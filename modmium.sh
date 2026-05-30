#!/bin/bash
# written by DMD and mariah carey
source /usr/share/misc/shflags
DEFINE_boolean userkeys "$FLAGS_FALSE" "Whether or not to use user-generated signing keys." "u"
DEFINE_boolean backup "$FLAGS_TRUE" "Whether or not to backup firmware from flashing devkeys." "b"
FLAGS $@

fail(){
	echo -e "$1"
	if [[ $2 != "keepflag" ]]; then
		vpd -d dev_firmware
	fi
	umount $BACKUP >/dev/null 2>&1
	sleep 3
	exit 1
}

# -- FLAGS --
menu_text="Modmium Install Script!"
# -----------------------

# TUI colors :D
B=$'\033[38;5;45m'
G=$'\033[38;5;46m'
Y=$'\033[38;5;220m'
R=$'\033[38;5;203m'
P=$'\033[38;5;135m'
N=$'\033[0m'
D=$'\033[1;90m'
UN=$'\033[4m' #underline
RUN=$'\033[24m' #reset underline
MILESTONE=$(grep MILESTONE /etc/lsb-release | cut -d= -f2 | tr -d '\r')

# -- skidded from modmium-update.sh --
BOARD="$(grep '^CHROMEOS_RELEASE_DESCRIPTION=' /etc/lsb-release | awk '{print $NF}')"
getImageLink(){
  jsonLink="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
  echo -e "${G}Checking crosbreaker/chromeos-releases-data for recovery image URL...${N}"
  recoveryUrl=$(curl -sL $jsonLink | jq -r --arg board $BOARD --arg ver $VERSION '
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
    sleep 1
  else
    fail "${R}Recovery URL not found or invalid :(${N}"
  fi
}

askBranch(){
  branchfile="stable"
  echo -e "[If you don't know what this means, just press enter]"
  echo -ne "Branch of Modmium to install (${G}stable${N}, nightly): "
  read -rep "" branchreq
  case $branchreq in
    nightly)
	  branch="nightly"
	  ;;
	stable)
	  branch="stable"
      ;;
	*)
	  branch="${branchfile}"
	  ;;
  esac
  echo # weird UI glitch if this isn't here, idk man
}

get_booted_kernnum() {
  if (( $(cgpt show -n "$intdis" -i 2 -P) > $(cgpt show -n "$intdis" -i 4 -P) )); then
    echo -n 2
  else
    echo -n 4
  fi
}
get_booted_rootnum() {
	echo $(( $(get_booted_kernnum) + 1 ))
}
opposite_num() {
  case $1 in
    2) echo -n 4 ;;
    3) echo -n 5 ;;
    4) echo -n 2 ;;
    5) echo -n 3 ;;
    *) echo -n "skid" ;;
  esac
}

installCros() {
  stop powerd &>/dev/null
  ldconfig
  echo -e "${D}Note: this script grabs the current kernver and signs the new version with it, so there's no issues with upgrading or downgrading.${N}"
  echo -ne "Version of ChromeOS you want to install: "
  read -rep "" VERSION
  [[ $VERSION =~ ^[0-9]+$ ]] || fail "${R}Version must be numeric, exiting...${N}" keepflag
  if [[ $VERSION -lt 131 ]]; then
    echo -e "${R}WARNING. VERSIONS BELOW 131 ARE NOT SUPPORTED.${N}\nDo not make an issue report if you run into problems."
    echo -e "${B}Continue anyways? [y/N]${N}"
    read -rep ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${B}Continuing...${N}"
    else
      fail "${R}Exiting...${N}" keepflag
    fi
  fi
  askBranch
  getImageLink
  intdis=$(rootdev -d)
  if echo "$intdis" | grep -q '[0-9]$'; then
    intdis_prefix="$intdis"p
	else
	  intdis_prefix="$intdis"
	fi

	installKern=${intdis_prefix}$(opposite_num $(get_booted_kernnum))
	installRoot=${intdis_prefix}$(opposite_num $(get_booted_rootnum))
	echo -e "${G}Installing ChromeOS to disk...${N}"
	cd /usr/local
	python -m venv .venv
	source .venv/bin/activate
	pip install requests &>/dev/null
	curl -Lo /root/stream.py "https://modmium.dev/tools/stream.py"
	python /root/stream.py --recovery-url "${recoveryUrl}" --kern-output "${installKern}" --root-output "${installRoot}" || fail "${R}Failed to install ChromeOS, refusing to change boot order, exiting...${N}" keepflag
	rm -rf .venv
	# thanks lxrd for that python script btw

	echo -e "${G}Removing verity from ChromeOS...${N}"
	# keydir gets defined in installModmium()
	/usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --partitions $(opposite_num $(get_booted_kernnum)) --keys ${keydir} &>/dev/null
	futility dump_kernel_config ${installKern} > config.txt
	sed -i "s|cros_secure|cros_secure cros_debug|g" config.txt
	sed -i 's/  */ /g; s/^ //; s/ $//' config.txt # fix double spacing
	stop trunksd &>/dev/null || stop tcsd &>/dev/null
	rawkv=$(tpmc read 0x1008 9)
	start trunksd &>/dev/null || start tcsd &>/dev/null
	# this part inspired by aurora (though obviously not copy pasted), thanks soap :3
	bytes=()
	for byte in $rawkv; do
	  while [[ -n $byte ]]; do
			bytes+=( "${byte:0:2}" )
			byte="${byte:2}"
		done
	done
	if [[ ${bytes[0]} -eq 10 ]]; then
	  kernver=$(( ${bytes[4]}<<0 | ${bytes[5]}<<8 ))
	elif [[ ${bytes[0]} -eq 2 ]]; then
	  kernver=$(( ${bytes[5]}<<0 | ${bytes[6]}<<8 ))
	fi
	# end aurora-inspired part
	futility vbutil_kernel --repack ${installKern} \
	  --keyblock ${keydir}/kernel.keyblock \
		--signprivate ${keydir}/kernel_data_key.vbprivk \
		--config config.txt \
		--version $kernver \
		--oldblob ${installKern} || fail "${R}Failed to remove verity, exiting...${N}" keepflag
	rm -rf config.txt

  echo -e "${G}Installing Modmium ($branch) to ChromeOS...${N}"
  export PATH="${PATH}:/usr/local/libexec/git-core" # just in case, so we know git https will work
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	if [[ -d /root/.ssh ]]; then
	  [[ ! -d /home/chronos/user/.ssh ]] && mkdir /home/chronos/user/.ssh
		git clone --depth 1 -b $branch --single-branch git@github.com:crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}" keepflag
	else
		git clone --depth 1 -b $branch --single-branch https://github.com/crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}" keepflag
	fi
	echo -e "${G}Successfully cloned repository!${N} Dropping new files..."

	cd modmium
	mount ${installRoot} mnt --mkdir
	for file in $(find mod-files -mindepth 1 -name "*"); do
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
  [[ $arch == *"ARM"* ]] && arch=aarch64
  cp build-utils/lib/minioverride-${arch}.so mnt/lib/minioverride.so
  rm -rf mnt/root/.force_update_firmware mnt/opt/google/cr50 mnt/opt/google/ti50
  [[ -d ${BACKUP}/userkeys ]] && cp -r ${BACKUP}/userkeys mnt/usr/share/vboot
  echo $branch > mnt/.branch

  echo -e "${G}Syncing filesystem (may take a while)...${N}"
  sync
  umount mnt
  cd .. && rm -rf modmium

  echo -e "${G}Done, reboot and you should boot into Modmium!${N}"
  crossystem disable_dev_request=1
  activekern=$(get_booted_kernnum)
  inactivekern=$(opposite_num "${activekern}")
  cgpt add -P 0 -T 0 -S 0 -i ${activekern} ${intdis}
  cgpt add -P 15 -T 5 -S 1 -i ${inactivekern} ${intdis}
  start powerd &>/dev/null
  sleep 2
  exit 0
}


# -- MAIN SCRIPT --
logo() {
    echo -e "
 ██████   ██████              █████                  ███
▒▒██████ ██████              ▒▒███                  ▒▒▒
 ▒███▒█████▒███   ██████   ███████  █████████████   ████  █████ ████ █████████████
 ▒███▒▒███ ▒███  ███▒▒███ ███▒▒███ ▒▒███▒▒███▒▒███ ▒▒███ ▒▒███ ▒███ ▒▒███▒▒███▒▒███
 ▒███ ▒▒▒  ▒███ ▒███ ▒███▒███ ▒███  ▒███ ▒███ ▒███  ▒███  ▒███ ▒███  ▒███ ▒███ ▒███
 ▒███      ▒███ ▒███ ▒███▒███ ▒███  ▒███ ▒███ ▒███  ▒███  ▒███ ▒███  ▒███ ▒███ ▒███
 █████     █████▒▒██████ ▒▒████████ █████▒███ █████ █████ ▒▒████████ █████▒███ █████
▒▒▒▒▒     ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒ ▒▒▒ ▒▒▒▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒ ▒▒▒ ▒▒▒▒▒
"
    echo -e $menu_text
}

checkWP(){
	writeprotect=$(flashrom --wp-status 2>&1 | grep "disabled")
	if [[ $writeprotect == *"disabled"* ]]; then
		echo -e "FWWP is currently ${G}DISABLED${N}, continuing..."
	else
		echo -e "FWWP is currently ${N}ENABLED${N}, checking for wp range..."
		wprange=$(flashrom --wp-status 2>&1 | grep -E "range: start=0x[0-9a-f]+, len=0x00000000")
		if [[ $wprange != "" ]]; then
			echo -e "WP range allows for flashing, continuing."
		else
			echo -e "WP range non-zero, checking for HWWP."
		    if [[ $(crossystem wpsw_cur) == "0" ]]; then
				echo -e "HWWP off, continuing."
		    else
				fail "HWWP and SWWP are enabled with WP range non-zero, please disable your WP by following this guide: ${G}https://crosmium.dev/FWWP${N}"
		    fi
		fi
	fi
}

checkAPROV(){
  if isti50=$(gsctool -a -I | grep AllowUnverifiedRo); then
    setting=$(echo $isti50 | awk '{print $3}')
    case $setting in
      Always) echo -e "APROV is currently ${G}DISABLED${N}, continuing..." ;;
      Never) fail "APROV is currently ${R}ENABLED${N}. If you're seeing this, WP is off but APROV is on and rebooting will ${R}${UN}BRICK YOUR DEVICE${RUN}${N}.\n Disable APROV immediately by running \`gsctool -a -I AllowUnverifiedRo:always\`" ;;
      *) fail "How did we get here..?" ;;
    esac
  else
    echo -e "Device is not Ti50, so APROV does not exist, continuing..."
  fi
}

askConfirmation(){
	read -r -n 2 -s -p "Double click y to continue, or hold any other key to quit." confirmation # don't put Y if confirm wants y
	echo ""
  if [[ "$confirmation" != "yy" ]]; then
    echo -e "Denied! exiting.."
		exit 0
  fi
}

get_largest_cros_blockdev() {
  local largest size dev_name tmp_size remo
  size=0
  command -v sfdisk >/dev/null 2>&1 || return 0
  for blockdev in /sys/block/*; do
  	dev_name="${blockdev##*/}"
    echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
    tmp_size=$(cat "$blockdev"/size)
    remo=$(cat "$blockdev"/removable)
    if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
      case "$(sfdisk -d "/dev/$dev_name" 2>/dev/null)" in
      	*'name="STATE"'*'name="KERN-A"'*'name="ROOT-A"'*)
          largest="/dev/$dev_name"
          size="$tmp_size"
        ;;
      esac
  	fi
  done
  echo "$largest"
}

selUserBackup(){
	echo -e "These are the vfat drives/partitions connected to your device:"
	for drive in $(lsblk -lo NAME,FSTYPE | grep vfat | awk '{print $1}'); do
		echo /dev/$drive
	done
	echo -e "Type the drive that the signing keys [userkeys] were backed up to (/dev/sdX or sdX are acceptable)...${N}"
	read -ep "Drive: " driveloc
	driveloc="${driveloc%/}"
	if [[ $driveloc == *"/dev/"* ]]; then
		if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
	else
		if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
	fi
}

modmiumInstall(){
  if [[ $FLAGS_userkeys == $FLAGS_TRUE ]]; then
    BACKUP=/tmp/backupdir
    mkdir -p $BACKUP
    echo -e "These are the vfat drives/partitions connected to your device:"
    for drive in $(lsblk -lo NAME,FSTYPE | grep vfat | awk '{print $1}'); do
      echo /dev/$drive
    done
    echo -e "Type the drive that the signing keys were backed up to (/dev/sdX or sdX are acceptable)...${N}"
   	read -ep "Drive: " driveloc
   	driveloc="${driveloc%/}"
   	if [[ $driveloc == *"/dev/"* ]]; then
			if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
   	else
     	if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
   	fi
    keydir=${BACKUP}/userkeys
  else
    keydir=/usr/share/vboot/devkeys
  fi
	if ! which git &>/dev/null || ! which file &>/dev/null; then
		echo -e "${R}Dependencies not installed, installing...${N}"
		source /etc/profile # required to get emerge working
		if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
		  printf 'y\n\nn' | dev_install --reinstall
			touch /mnt/stateful_partition/.devinstall_complete
		fi
		ldconfig # reload shared libraries to include python libs
		emerge git file
		cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
	fi
	[[ $FLAGS_userkeys == $FLAGS_TRUE ]] && selUserBackup
	installCros # :whale:
}
selectBackup(){
	BACKUP=/tmp/backupdir
	mkdir -p $BACKUP
	[[ $FLAGS_backup == $FLAGS_FALSE && $FLAGS_userkeys == $FLAGS_FALSE ]] && return
	if [[ $FLAGS_userkeys == $FLAGS_FALSE ]]; then
		cat <<EOF | xargs -0 echo -ne
Would you like to ${R}ERASE${N} an external (D)rive and backup to it, or backup to a directory? (D = drive, P = directory)"
Backing up to a (D)rive is highly recommended, but if you know what you're doing, [or already have a mount (P)oint], you can use a directory
EOF
		read -ep "(d/p): " resp
  	if [[ $resp =~ ^[Dd]$ ]]; then
      drivelist=$(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "$(get_largest_cros_blockdev)|loop|ram" || fail "${R}No connected drives, exiting...${N}")
      cat <<EOF | xargs -0 echo -ne
These are the drives connected to your device:
$drivelist
What drive would you like write the backup onto? Type /dev/sdX or sdX not the USB's name ${R}(THIS WILL ERASE THE DRIVE!!!!)${N}
EOF
      read -ep "Drive: " driveloc
      driveloc="${driveloc%/}"
      if [[ $driveloc == *"/dev/"* ]]; then
				mkfs.vfat -I -F 32 $driveloc || fail "${R}Unable to wipe device, exiting...${N}"
        mkdir -p $BACKUP
				mount $driveloc $BACKUP || fail "${R}Unable to mount device, exiting...${N}"
			else
      	mkfs.vfat -I -F 32 /dev/$driveloc || fail "${R}Unable to wipe device, exiting...${N}"
      	mkdir -p /tmp/backupdir
       	mount /dev/$driveloc $BACKUP || fail "${R}Unable to mount device, exiting...${N}"
    	fi
 			if ! ( [ -d ${BACKUP} ] && touch ${BACKUP}/.test ); then
				fail "${R}Unable to write to backup, exiting...${N}"
			fi
			DRIVEBACKUP=1
		elif [[ $resp =~ ^[Pp]$ ]]; then
    	echo -e "What directory would you like to backup to?"
    	read -ep "Dir: " BACKUP
			if ! ( [ -d ${BACKUP} ] && touch ${BACKUP}/.test ); then
				fail "${R}Unable to write to backup, exiting...${N}"
			else
    		echo -e "Valid directory!"
			fi
		else
			fail "Invalid response, exiting..."
		fi
	else
		echo -e "These are the vfat drives/partitions connected to your device:"
		for drive in $(lsblk -lo NAME,FSTYPE | grep vfat | awk '{print $1}'); do
			echo /dev/$drive
		done
		echo -e "Type the drive that the signing keys were backed up to (/dev/sdX or sdX are acceptable)...${N}"
  	read -ep "Drive: " driveloc
  	driveloc="${driveloc%/}"
  	if [[ $driveloc == *"/dev/"* ]]; then
			if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
  	else
    	if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
  	fi
		if ! ( [ -d ${BACKUP} ] && touch ${BACKUP}/.test ); then
			fail "${R}Unable to write to backup.${N}"
		fi
		DRIVEBACKUP=1
	fi
	if [[ $(df $BACKUP | awk '{print $4}' | tail -n 1) -lt 16384 ]]; then
		fail "${R}NOT ENOUGH EMPTY SPACE ON DRIVE. Exiting...${N}"
	fi
}

flashDevFW(){
	DEVFW=$(vpd -i RO_VPD -g "dev_firmware" 2>&1)
	(
		device_management_client --action=remove_firmware_management_parameters >/dev/null 2>&1 || \
		cryptohome --action=remove_firmware_management_parameters >/dev/null 2>&1
		device_management_client --action=set_firmware_management_parameters --flags=0x0 >/dev/null 2>&1 || \
		cryptohome --action=set_firmware_management_parameters --flags=0x0 >/dev/null 2>&1
	) \
	|| \
	( initctl stop tcsd >/dev/null 2>&1
		initctl stop trunksd >/dev/null 2>&1
		tpmc clear; tpmc def 0x100a 0x28 0x12000
		tpmc write 0x100a 76 28 10 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	) # we do this to *ensure* that FWMP is gone even if device_management_client is bugging out

	if [[ $DEVFW != 1 ]]; then
		# flash gbb flags, devkeys, and set dev_firmware to 1 to prevent accidental reflashing :3
  	if [[ $FLAGS_userkeys == $FLAGS_FALSE ]]; then
			/usr/share/vboot/bin/make_dev_ssd.sh --force -r
			/usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid --backup_dir $BACKUP --to /tmp/devfw.bin
			futility gbb -s /tmp/devfw.bin --flags=0xa0b1
			flashrom -w /tmp/devfw.bin
		else
			/usr/share/vboot/bin/make_dev_ssd.sh --force -r --keys ${BACKUP}/userkeys
			/usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid --backup_dir $BACKUP --keys ${BACKUP}/userkeys --to /tmp/devfw.bin
			futility gbb -s /tmp/devfw.bin --flags=0xa0b1
			flashrom -w /tmp/devfw.bin
		sync # sync because I dont trust ChromeOS
		fi
		vpd -i RO_VPD -s dev_firmware=1
  else
    fail "You are already using DevFW!" keepflag
  fi
  sleep 0.5

}

main(){
  clear
  logo
  cat <<EOF | xargs -0 echo -ne
This requires write protection to be disabled, and it will be checked before this script attempts anything
Checking for Firmware Write Protection...
EOF
	checkWP
	checkAPROV

	echo -e "Are you sure you want to flash DevFW firmware?"
	askConfirmation

	echo -e "Getting backup selection..."
	selectBackup

  echo -e "Backup selection complete, flashing DevFW..."
  flashDevFW

  touch /tmp/.rebootpls
  cat <<EOF | xargs -0 echo -ne
If everything succeeded, you are now running DevFW!
It is highly recommended to go backup the firmware that is now in your selected drive (or directory) to the cloud, or another safe place.
${B}Please reboot your chromebook${N}. After you reboot, either recover with a Modmium image OR run this script again to INSTALL Modmium. (If you used userkeys, make sure you also use that flag when trying to Install Modmium with this script)
EOF
  echo -e "Exiting..."
  sleep 0.5
  exit 0
}

clear
DEVFW=$(vpd -i RO_VPD -g "dev_firmware")
if [[ -f /tmp/.rebootpls ]]; then
  echo -e "Please reboot your device before running this script again!"
  exit 1
fi
if [[ "$DEVFW" -eq 1 ]]; then
  modmiumInstall
else
  main
fi
