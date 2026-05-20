#!/bin/bash

source /usr/share/misc/shflags
DEFINE_boolean userkeys "$FLAGS_FALSE" "Whether or not to use user-generated signing keys." "u"
FLAGS $@

# -- FLAGS --
menu_text="Modmium pre-enrollment script!"
# -----------------------

# TUI colors :D
B='\033[1;36m'
G='\033[1;32m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'
D='\033[1;90m'

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

fail(){
	echo -e "$1"
	if [[ $2 != "keepflag" ]]; then
		vpd -d dev_firmware
	fi
	umount $BACKUP >/dev/null 2>&1
	sleep 1
	exit 1
}

checkWP(){
	writeprotect=$(flashrom --wp-status 2>&1 | grep "disabled")
	if [[ $writeprotect == *"disabled"* ]]; then
		echo -e "FWWP is currently ${G}DISABLED${N}, continuing..."
	else
		echo -e "FWWP is currently ${N}ENABLED${N}, checking for wp range..."
		wprange=$(flashrom --wp-status 2>&1 | grep -E "range: start=0x[0-9a-f]+, len=0x00000000")
		if [[ $wprange != "" ]]; then
			fail "WP range is set to 0,0 but you must fully disable FWWP before continuing."
		else
			fail "WP range is still set, please disable your FWWP by following this guide: ${G}https://crosmium.dev/FWWP${N}"
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
selectBackup(){
	BACKUP=/tmp/backupdir
	mkdir -p $BACKUP
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
	DEVFW=$(vpd -i RO_VPD -g "dev_firmware")
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
		( /usr/share/vboot/bin/set_gbb_flags.sh 0xa0b1 || /usr/share/vboot/bin/set_gbb_flags.sh 0x80b1 ) \
		  || ( futility gbb -s --flash --flags=0xa0b1 || futility gbb -s --flash --flags=0x80b1 )
			# we try a0b1 first, but if it doesn't recognize the fastboot flag, we do 80b1 instead
  	if [[ $FLAGS_userkeys == $FLAGS_FALSE ]]; then
			/usr/share/vboot/bin/make_dev_ssd.sh --force
			/usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid --backup_dir $BACKUP
		else
			/usr/share/vboot/bin/make_dev_ssd.sh --force --keys ${BACKUP}/userkeys
			/usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid --backup_dir $BACKUP --keys ${BACKUP}/userkeys
		fi
		sync # sync because I dont trust ChromeOS
  	vpd -i RO_VPD -s "dev_firmware"=1
  else
    fail "You are already using DevFW (Devkeys)!" keepflag
  fi
  sleep 0.5
  if [[ $DRIVEBACKUP == 1 ]]; then
    umount $BACKUP
  fi
}

main(){
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

  cat <<EOF | xargs -0 echo -ne
If everything succeeded, you are now running DevFW!
It is highly recommended to go backup the firmware that is now in your selected drive (or directory) to the cloud, or another safe place.
Whenever you're ready, enter recovery and plug in your modmium usb!
EOF
}

clear
main
