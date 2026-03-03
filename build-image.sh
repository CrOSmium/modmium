#!/bin/bash
# once again, a conceptual overview for now, seeing as we don't want to write a bunch of code for nothing if ts gets serverside patched by the big Goog :fanxql:

# pre-flight checklist
if [ "$(basename $PWD)" != "modmium" ]; then
	echo "Please run this script in the cloned directory (modmium/)"
	exit 1
fi
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, elevating with sudo..."
	 sudo "$0" "$@"
	 exit $?
fi
source ./build-utils/common_modmium.sh
# args=$@ 
# I FUCKING HATE BASH ASLDFJNMASKLDFH;GNFGDJKLADF;NHLK;ADFNH;JKDJK;N;GKANDFGJKN WHAT DO YOU MEAN YOU JUST MAKE $@ STOP EXISTING WHEN INSIDE OF A FUNCTION??? ARE YOU STUPID??????
# after a day of thinking i realize it's because $@ is the arguments passed into the function, of which there are none unless i did something like getFlags($@). i think. lemme test it.
# yep that was it. just gonna remove this variable because it's redudant now. these comments are staying because it's funny though xD
# end of checks

# begin functions
# begin flag functions
getFlags(){
	load_shflags
	# thanks sh1mmer wax.sh for teaching me how to use shflags lmao
	FLAGS_HELP="Usage:
$0 -i <path/to/recovery.bin> [flags] 
OR
$0 -b <board> -v <version> [flags]"
	DEFINE_string image "" "Path to recovery image (use if not autobuilding)" "i" 
	DEFINE_string board "" "Name of board to autobuild (use if not manual building)" "b"
	DEFINE_string version "" "MILESTONE of version to autobuild (use if not manual building)" "v"
	DEFINE_string kernver "" "Kernver to sign kernels with (leave blank to not change). Don't put a leading 0x0001000 (\"0x00010007\" bad, \"7\" good)." "k"
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
	if [[  -n $FLAGS_image  && ! ( -f $FLAGS_image ) ]]; then
		echo -e ""$R"File not found"$N", please provide a path to an actual recovery image."
		exit 1
	elif [[ -n $FLAGS_image && ( $FLAGS_image == "modmium.bin" ) ]]; then
		echo -e ""$R"Input image cannot have the same name as output image."$N" Rename it to something other than "$B"modmium.bin"$N""
		exit 1
	fi
	if [[ -n $FLAGS_version && ! ( $FLAGS_version =~ ^[0-9]+$ ) ]]; then
		echo -e ""$R"Version not a natural number"$N", please provide chromeOS "$B"MILESTONE"$N" you want to build."
		exit 1
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
			echo -e ""$R"Invalid board name."$N" See "$B"https://dl.crosbreaker.dev/recovery-images"$N" for a complete list."
			exit 1
		fi
	fi
	if [[ -n $FLAGS_kernver ]]; then
		if ! [[ $FLAGS_kernver =~ ^[0-9A-Fa-f]{1,}$ ]]; then
    	echo -e "${R}Kernver is not hex or contains leading \"0x\".${N}"
			exit 1
		fi
	fi
}
# end flag functions

# begin build functions
removeVerity(){
	if [[ -n $FLAGS_image ]]; then
		tempDir=$(mktemp -d)
		newImage="$tempDir"/modmium-$(basename $FLAGS_image)
		echo -e ""$G"Copying image to tempdir, "$R"this may take a while..."$N""
		cp $FLAGS_image $newImage
		sync
	else
		newImage=modmium.bin
		mv $downloadedImage $newImage
	fi
	echo -e ""$G"Setting up loop device..."$N""
	loopDev=$(losetup -Pf --show $newImage) 
	echo -e ""$G"Disabling verity..."$N""
	build-utils/ssd_util.sh -i $loopDev -r --partitions 2
	build-utils/ssd_util.sh -i $loopDev -r --partitions 4 --recovery_key

	rootUUID=$(blkid -s PARTUUID -o value ${loopDev}p3)
	for part in 2 4; do
    echo -e ""$G"Dumping and modifying kernel ${part} commandline..."$N""
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

		echo -e ""$G"Resigning kernel ${part} with modified commandline..."$N""
    vbutil_kernel --repack ${loopDev}p$part \
        --keyblock build-utils/keys/$( [ $part -eq 2 ] && echo "recovery_kernel.keyblock" || echo "kernel.keyblock" ) \
        --signprivate build-utils/keys/$( [ $part -eq 2 ] && echo "recovery_kernel_data_key.vbprivk" || echo "kernel_data_key.vbprivk" ) \
        --config config_${part}.txt \
				--version $kernver \
        --oldblob ${loopDev}p$part
	done

	echo -e ""$G"Cleaning up kernel backups and configs..."$N""
	rm -rf cros_sign_backups config*
}
dropModFiles(){
	echo -e ""$G"Mounting loop device..."$N""
	mount "$loopDev"p3 mnt --mkdir
	modFiles=$(find mod-files -mindepth 1 -name "*")
	echo -e ""$G"Dropping modfiles..."$N""
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
		rm -rf mnt/root/.force_update_firmware # RECOVERY WILL FAIL IF YOU REMOVE THIS LINE
	done
	sleep 0.5
	# cleanup time!
	echo -e ""$G"Cleaning up..."$N""
	umount mnt
	losetup -d $loopDev
	if [[ -n $FLAGS_image ]]; then
		echo -e ""$G"Moving image from RAM to $(basename $newImage) in current directory..."$N""
		mv $newImage $(basename $newImage)
		sync
		rm -rf $tempDir mnt
	else
		rm -rf mnt
	fi
	echo -e ""$G"Finished!"$N""
}
# end build functions

# begin downloading functions
downloadImage(){
	jsonLink="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
	echo -e ""$G"Checking crosbreaker/chromeos-releases-data for recovery image URL..."$N""
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
		echo -e ""$G"Recovery URL found!"$N""
	else
		echo -e ""$R"Recovery URL not found or invalid :(
Exiting..."$N""
		exit 1
	fi
	echo -e ""$G"Downloading image..."$N""
	wget --show-progress -O recovery.zip $recoveryUrl
	echo -e ""$G"Unzipping image..."$N""
	7z x recovery.zip
	downloadedImage=$(basename $(find -name "chromeos*.bin"))
	echo -e ""$G"Removing zip file..."$N""
	rm -rf recovery.zip
	echo -e ""$G"Done! Continuing to build..."$N""
}
# end downloading functions

main(){
	getFlags $@
	checkFlagValidity
	if [[ -n $FLAGS_image ]]; then
		removeVerity
		dropModFiles
	elif [[ -n $FLAGS_board && -n $FLAGS_version ]]; then
		downloadImage
		removeVerity
		dropModFiles
	fi
}

main $@
