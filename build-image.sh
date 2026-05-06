#!/bin/bash

DEPENDENCIES=$(echo "funzip" "futility" "jq" "pv" "wget")

# pre-flight checklist
source ./build-utils/common_modmium.sh
branch=$(git rev-parse --abbrev-ref HEAD)

if [[ "$(basename $PWD)" != "modmium" ]]; then
	fail "Please run this script in the cloned directory (modmium/)"
fi
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, elevating with sudo..."
	 echo $USER >.realuser
	 sudo "$0" "$@"
	 exit $?
fi
if [[ -f .realuser ]]; then
	USER=$(cat .realuser)
fi

asUser(){
	silence su $USER -c "$1" # we do this to make sure permisisons aren't janky
}

checkDependencies(){
	for dep in $DEPENDENCIES; do
		if ! silence command -v $dep; then
			echo -e "${R}${dep} not found.${N}"
			local shouldExit=true
		fi
	done
	if [[ $shouldExit == "true" ]]; then
		fail "Exiting..."
	fi
}

cleanup(){ # to be used in case of failure, not for successful building
	silence umount mnt
	silence losetup -d $loopDev
	silence rm -rf mnt .realuser
	for tempbin in $(find /tmp/tmp.*/ -mindepth 1 -name 'modmium*.bin' 2>/dev/null); do
		silence rm -rf ${tempbin%/*} # deletes the tempdir that contains the modmium bin and not others
	done
}
trap cleanup EXIT

credits(){
  cat <<EOF | xargs -0 echo -ne
Credits:
${R}mariahscarycarey: ${P}Lead developer; laid out everything (prior to kxtz) conceptually, made image builder, worked on policy-test-tool with lxrd, MANY small changes and fixes.${N}
\033[38;5;78mdmd: Project lead; made MOSH/libmosh, devfw stuff, mpkeys manager, a bunch of small changes.${N}
\033[38;5;126mkxtzownsu: Made the buildcharge package, updater, and did code review to make sure we weren't skidding.${N}
${Y}lxrd: Discovered policy-test-tool and created device policy editing script.${N}
\033[38;5;93mxz8f: Helped with custom bootsplashes.${N}
\033[38;5;94mcon: emotional support (also helped with minor bugs in image downloader)${N}
\033[38;5;51mCasper1051, \033[38;5;93mMoonstone, \033[38;5;57mpilgorr${N}: creating the default bootsplashes.
EOF
}

fail(){
	echo -e "$1"
	cleanup
	exit 1
}

silence(){
	"$@" >/dev/null 2>&1
}
# end of checks

# begin flag functions
getFlags(){
	load_shflags
	# thanks sh1mmer wax.sh for teaching me how to use shflags lmao
	FLAGS_HELP=$(cat <<EOF
Usage:
$0 -i <path/to/recovery.bin> [flags]
OR
$0 -b <board> -v <version> [flags]"
EOF
  )
	DEFINE_string image "" "Path to recovery image (use if not autobuilding)" "i"
	DEFINE_string board "" "Name of board to autobuild (use if not manual building)" "b"
	DEFINE_string version "" "MILESTONE of version to autobuild (use if not manual building)" "v"
	DEFINE_string kernver "" "Kernver to sign kernels with (leave blank to not change). Don't put a leading 0x0001000 (\"0x00010007\" bad, \"7\" good)." "k"
	DEFINE_boolean userkeys "$FLAGS_FALSE" "Whether or not to generate user-made signing keys (plug in the drive to back them up to before starting building)." "u"
	DEFINE_string json "" "Path to chrome://policy exported json (optional)." "j"
	DEFINE_boolean bootsplash "$FLAGS_FALSE" "Whether or not to install bootsplash(es) in bootsplash/ (optional, requires inkscape)." "s"
	FLAGS $@ || exit $?
	if ! [[
		( -z $FLAGS_board && -z $FLAGS_version && -n $FLAGS_image ) ||
		( -n $FLAGS_board && -n $FLAGS_version && -z $FLAGS_image )
	]]; then
    flags_help
    exit 1
	fi
}

checkFlagValidity(){
	if [[  -n $FLAGS_image && ! ( -f "$FLAGS_image" ) ]]; then
		fail "${R}File not found, please provide a path to an actual recovery image.${N}"
	elif [[ -n $FLAGS_image && ( $FLAGS_image == "modmium.bin" ) ]]; then
		fail "${R}Input image cannot have the same name as output image.${N} Rename it to something other than ${B}modmium.bin${N}"
	fi
	if [[ -n $FLAGS_version && ! ( $FLAGS_version =~ ^[0-9]+$ ) ]]; then
		fail "${R}Version not a natural number${N}, please provide chromeOS ${B}MILESTONE${N} you want to build."
	fi
	if [[ -n $FLAGS_board ]]; then
		FLAGS_board=$(echo "$FLAGS_board" | tr '[:upper:]' '[:lower:]') # This is needed due to the json file storing all boards as lowercase values
		local boardInList=0
		for board in $boards; do
			if [[ "$FLAGS_board" == "$board" ]]; then
				boardInList=1
			fi
		done
		if [[ $boardInList != 1 ]]; then
			fail "${R}Invalid board name.${N} See ${B}https://dl.crosbreaker.com/recovery-images${N} for a complete list."
		fi
	fi
	if [[ -n $FLAGS_kernver ]]; then
		if ! [[ $FLAGS_kernver =~ ^[0-9A-Fa-f]{1,}$ && ${#FLAGS_kernver} -lt 3 ]]; then
    	fail "${R}Kernver is not hex or contains leading \"0x\".${N}"
		fi
	fi
	if [[ -n $FLAGS_json && ! ( -f "$FLAGS_json" ) ]]; then
		fail "${R}Policy json file doesn't exist.${N}"
	fi
	if [[ $FLAGS_bootsplash == $FLAGS_TRUE ]]; then
		if ! silence inkscape --version; then
			fail "${R}Inkscape NOT installed, either don't use a custom bootsplash or install inkscape.${N}"
		fi
	fi
	if [[ $FLAGS_bootsplash == $FLAGS_TRUE  && ! ( -d bootsplash/ ) ]]; then
		fail "${R}Bootsplash directory doesn't exist.${N}"
	elif [ $FLAGS_bootsplash == $FLAGS_TRUE ] && [ -z "$(find bootsplash/$branch -mindepth 1)" ]; then
		fail "${R}Bootsplash directory is empty or doesn't have $branch bootsplashes.${N}"
	fi
}
# end flag functions

# begin build functions
removeVerity(){
	if [[ $FLAGS_userkeys == $FLAGS_TRUE ]]; then
		keydir=build-utils/keys/userkeys
	else
		keydir=build-utils/keys/devkeys
	fi
	if [[ -n $FLAGS_image ]]; then
		if [[ $(($(df /tmp | awk '{print $4}' | tail -n 1) * 1024)) -gt $(du -b ${FLAGS_image} | awk '{print $1}') ]]; then # checks if tmp has enough room for the image
			tempDir=$(mktemp -d)
		else
			echo -e "${B}/tmp is not large enough, using disk...${N}"
			mkdir -p tmp
			tempDir="tmp"
		fi
		newImage="$tempDir"/modmium-$(basename $FLAGS_image)
		echo -e "${G}Copying image to tempdir, ${R}this may take a while...${N}"
		cp "$FLAGS_image" $newImage
		sync
	else
		newImage=modmium.bin
		mv $downloadedImage $newImage
	fi
	echo -e "${G}Setting up loop device...${N}"
	loopDev=$(losetup -Pf --show $newImage || fail "${R}Failed to set up loop device, exiting...${N}")
	echo -e "${G}Disabling verity...${N}"
	silence build-utils/ssd_util.sh -i $loopDev -r --partitions 2 --keys ${keydir}
	silence build-utils/ssd_util.sh -i $loopDev -r --partitions 4 --recovery_key --keys ${keydir}

	rootUUID=$(blkid -s PARTUUID -o value ${loopDev}p3)
	for part in 2 4; do
    echo -e "${G}Dumping and modifying kernel ${part} commandline...${N}"
		futility dump_kernel_config ${loopDev}p$part > config_${part}.txt
		[ $part -eq 2 ] && sed -i "s|root=PARTUUID=[^ ]*|root=PARTUUID=$rootUUID|g" config_2.txt
		if [ $part -eq 4 ]; then
			sed -i "
				s|cros_secure|cros_secure cros_debug|g
			" config_4.txt
		fi
		sed -i 's/  */ /g; s/^ //; s/ $//' config_${part}.txt # fix double spacing

		if [[ -n $FLAGS_kernver ]]; then
			kernver=$FLAGS_kernver
		else
			kernver=$(futility show ${loopDev}p$part | grep "Kernel version" | sed 's/^.*:      //')
		fi

		echo -e "${G}Resigning kernel ${part} with modified commandline...${N}"
    vbutil_kernel --repack ${loopDev}p$part \
        --keyblock ${keydir}/$( [ $part -eq 2 ] && echo "recovery_kernel.keyblock" || echo "kernel.keyblock" ) \
        --signprivate ${keydir}/$( [ $part -eq 2 ] && echo "recovery_kernel_data_key.vbprivk" || echo "kernel_data_key.vbprivk" ) \
        --config config_${part}.txt \
				--version $kernver \
        --oldblob ${loopDev}p$part
	done

	echo -e "${G}Cleaning up kernel backups and configs...${N}"
	rm -rf cros_sign_backups config*
}

dropModFiles(){
	echo -e "${G}Mounting loop device...${N}"
	mount "$loopDev"p3 mnt --mkdir
	if [[ ! -f mod-files/root/policy.json ]]; then
		if [[ -z $FLAGS_json ]]; then
			echo -e "${B}Policy json not found, running policy editor will NOT install enterprise extensions... Continue anyway? (y/N)${N}"
			read -n 1 -r
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				echo
				fail "${R}Cleaning up and exiting...${N}"
			else
				echo
				echo -e "${G}Continuing...${N}"
			fi
		else
			echo -e "${B}Moving policy json to mod-files/root/policy.json...${N}"
			mv "$FLAGS_json" mod-files/root/policy.json
		fi
	fi
	modFiles=$(find mod-files -mindepth 1 -name "*")
	echo -e "${G}Dropping modfiles...${N}"
	for file in $modFiles; do
		if [[ -d $file ]]; then
			:
		elif [[ -f $file ]]; then
			oldFile=$(echo $file | sed 's/mod-files/mnt/')
			dir=$(dirname $oldFile)
			if [[ -f $oldFile ]]; then
				mv $oldFile "$oldFile".old
			fi
			mkdir -p $dir
			cp $file $oldFile
			chown 0:0 $oldFile
			chmod 777 $oldFile
		fi
	done
	arch=$(file mnt/bin/bash | awk -F', ' '{print $2}')
	cp build-utils/lib/minioverride-${arch}.so mnt/lib/minioverride.so
	rm -rf mnt/root/.force_update_firmware mnt/opt/google/cr50 mnt/opt/google/ti50 # RECOVERY WILL FAIL IF YOU REMOVE THIS LINE
	sleep 0.5
	# cleanup time!
	echo -e "${G}Cleaning up...${N}"
	if [[ $FLAGS_bootsplash == $FLAGS_TRUE ]]; then
		rm -rf mod-files/bootsplash/*.png
	fi

	echo $branch >mnt/.branch

	umount mnt
	losetup -d $loopDev
	if [[ -n $FLAGS_image ]]; then
		echo -e "${G}Moving image from tempdir to $(basename $newImage) in current directory...${N}"
		mv $newImage $(basename $newImage)
		sync
		rm -rf $tempDir mnt
	else
		rm -rf mnt
	fi
	rm -rf .realuser
	echo -e "${G}Finished!${N}"
}
# end build functions

# begin optional build functions
bootsplash(){
	echo -e "${G}Converting svg to png requires a resolution, input your chromebook's resolution (put a space between the width and height, for example 1920 1200 not 1920x1200)${N}"
	local unresolved=true # lmao i love puns, basically this is to keep the while loop running until the resolution is valid
	while [[ $unresolved == "true" ]]; do
		echo -ne "Resolution: ${N}"
		read -rep "" width height
		for dimension in width height; do
			if [[ ( -n ${!dimension} && ! ( ${!dimension} =~ ^[0-9]+$ ) && ${!dimension} -lt 10000 ) || -z ${!dimension} ]]; then
				echo -e "${R}Invalid ${dimension}!${N}"
				export ${dimension}Valid=false
			else
				export ${dimension}Valid=true
			fi
		done
		if [[ ( $widthValid == "true" ) && ( $heightValid == "true" ) ]]; then
			unresolved=false
		fi
	done
	for splash in $(find bootsplash/$branch -mindepth 1 -name '*.svg'); do
		echo -e "Converting ${G}$(basename $splash)${N} to png..."
		mkdir -p mod-files/bootsplash
		silence inkscape -w $width -h $height $splash -o mod-files/bootsplash/$(basename ${splash%.*}.png)
	done
}

genUserKeys(){
	echo -e "${G}Generating user keys...${N}"
	silence pushd build-utils/keygeneration
	if [[ -d ApRoV1Signing-PreMP ]]; then
		rm -rf ApRoV1Signing-PreMP
	fi
	asUser "bash make_arv_root.sh"
	asUser "bash create_new_keys.sh --arv-root-path ./ApRoV1Signing-PreMP"
	cd accessory
	asUser "bash create_new_ec_efs_key.sh"
	asUser "openssl genrsa -f4 -out ec_data_key.pem 2048 && futility create --desc \"EC Data Key\" --hash_alg 2 ec_data_key.pem ec_data_key"
	cd ..
	asUser "mkdir -p ../keys/userkeys"
	for key in $(find . -mindepth 1 -name '*.v*' -o -name '*.keyblock' -o -name '*ec_*' ! -name '*ec_*.sh'); do
		asUser "mv $key ../keys/userkeys"
	done
	silence popd
}

backupUserKeys(){
	# lol this one is taken from modmium.sh
	BACKUPDIR=/tmp/backupdir
  echo -e "These are the external drives connected to your device:"
  lsblk -dpno NAME,SIZE,MODEL | grep "/dev/sd"
  echo -e "What drive would you like write the backup onto? Type /dev/sdX or sdX, not the USB's name ${R}(THIS WILL ERASE THE DRIVE!!!!)${N}"
  read -ep "Drive: " driveloc
  driveloc="${driveloc%/}"
	echo -e "Are you absolutely ${UN}CERTAIN${RUN} you want to ${R}WIPE ${driveloc}${N}?"
	read -r -n 2 -s -p "(Press yy to continue)"; echo
	if [[ $REPLY != yy ]]; then
		fail "${R}Exiting...${N}"
	fi
  if [[ $driveloc == *"/dev/"* ]]; then
		if ! mkfs.vfat -I -F 32 $driveloc; then fail "${R}Unable to wipe device...${N}"; fi
    mkdir -p $BACKUPDIR
		if ! mount $driveloc $BACKUPDIR; then fail "${R}Unable to mount device...${N}"; fi
  else
    if ! mkfs.vfat -I -F 32 /dev/$driveloc; then fail "${R}Unable to wipe device...${N}"; fi
    mkdir -p /tmp/backupdir
    if ! mount /dev/$driveloc $BACKUPDIR; then fail "${R}Unable to mount device...${N}"; fi
  fi
  DRIVEBACKUP=1
  sync
	if ! ( [ -d ${BACKUPDIR} ] && touch ${BACKUPDIR}/.test ); then
		fail "${R}Unable to write to backup.${N}" # exits if isn't writable (this is redundant but i am paranoid)
	fi
	echo -e "${G}Backing up signing keys, when installing devfw add -u/--userkeys when calling modmium.sh and ${UN}have the drive plugged in${RUN}...${N}"
	cp -r build-utils/keys/userkeys $BACKUPDIR
	umount $BACKUPDIR
}

buildBootloader(){ # unused until we actually need buildcharge, but useful
	silence pushd build-utils/buildcharge
	make fullclean
	cp configs/default.${arch} .config
	sed -i \
		'/^.*MODMIUM_BOOTLOADER/s/n/y/' \
		'/^.*MODMIUM_UPDATER/s/n/y' \
		'/^.*CONFIG_KERNEL/s/y/n' \
		.config
	make $arch -j`nproc` KERNEL_VERSION=$kernver USE_DEFAULT_CONFIG=0
	mv build/ramfs/buildcharge.${arch}.cpio* ../..
	silence popd
}
# end optional build functions

# begin downloading functions
downloadImage(){
	jsonLink="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
	echo -e "${G}Checking crosbreaker/chromeos-releases-data for recovery image URL...${N}"
	recoveryUrl=$(curl -sL $jsonLink | jq -r --arg board $FLAGS_board --arg ver $FLAGS_version '
		.[$board].images // []
		| map(select(
			.channel == "stable-channel" and
			(.chrome_version | startswith($ver + "."))
		))
		| sort_by(.last_modified)
		| last
		| .url // empty
	')
	if [[ -n $recoveryUrl && $recoveryUrl =~ dl\.google\.com ]]; then
		echo -e "${G}Recovery URL found!${N}"
	else
		fail "${R}Recovery URL not found or invalid :(
Exiting...${N}"
	fi
	echo -e "${G}Downloading image...${N}"
	wget --show-progress -O recovery.zip $recoveryUrl
	echo -e "${G}Unzipping image...${N}"
	pv recovery.zip | funzip > recovery.bin
	downloadedImage="recovery.bin"
	echo -e "${G}Removing zip file...${N}"
	rm -rf recovery.zip
	echo -e "${G}Done! Continuing to build...${N}"
}
# end downloading functions

main(){
	getFlags $@
	checkFlagValidity
	checkDependencies
	if [[ $FLAGS_userkeys == $FLAGS_TRUE ]]; then
		if [[ ! -d build-utils/keys/userkeys ]]; then
			genUserKeys
		fi
		backupUserKeys
	fi
	if [[ $FLAGS_bootsplash == $FLAGS_TRUE ]]; then
		bootsplash
	fi
	if [[ -n $FLAGS_board && -n $FLAGS_version ]]; then
		downloadImage
	fi
	removeVerity
	dropModFiles
}

main $@
credits
