#!/bin/bash

source /usr/share/misc/shflags
DEFINE_boolean userkeys "$FLAGS_FALSE" "Whether or not to use user-generated signing keys." "u"
FLAGS $@
if [[ $FLAGS_userkeys == $FLAGS_TRUE ]]; then
	userkeys=true
else
	userkeys=false
fi

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
		echo -e "FWWP is currently ${R}DISABLED${N}, continuing..."
	else
		echo -e "FWWP is currently ${G}ENABLED${N}, checking for wp range..."
		wprange=$(flashrom --wp-status 2>&1 | grep -E "range: start=0x[0-9a-f]+, len=0x00000000")
		if [[ $wprange != "" ]]; then
			fail "WP range is set to 0,0 but you must fully disable FWWP before continuing."
		else
			fail "WP range is still set, please disable your FWWP by following this guide: ${G}https://crosmium.dev/FWWP${N}"
		fi
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

doubleecho(){
	echo
	echo -e "$@"
}

selectBackup(){
	BACKUP=/tmp/backupdir
	mkdir -p $BACKUP
	if [[ $userkeys == "false" ]]; then
		echo -e "Would you like to ${R}ERASE${N} an external (D)rive and backup to it, or backup to a directory? (D = drive, P = directory)"
  	echo -e "Backing up to a (D)rive is highly recommended, but if you know what you're doing, [or already have a mount (P)oint], you can use a directory"
		read -ep "(D/P): " resp 
  	if [[ $resp =~ ^[Dd]$ ]]; then
      echo -e "These are the drives connected to your device:"
      lsblk -dpno NAME,SIZE,MODEL | grep "/dev/sd"
      echo -e "What drive would you like write the backup onto? Type /dev/sdX or sdX not the USB's name ${R}(THIS WILL ERASE THE DRIVE!!!!)${N}"
      read -ep "Drive: " driveloc
      driveloc="${driveloc%/}"
      if [[ $driveloc == *"/dev/"* ]]; then
				if ! mkfs.vfat -I -F 32 $driveloc; then fail "${R}Unable to wipe device, exiting...${N}"; fi
        mkdir -p $BACKUP
				if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device, exiting...${N}"; fi
			else
      	if ! mkfs.vfat -I -F 32 /dev/$driveloc; then fail "${R}Unable to wipe device, exiting...${N}"; fi
      	mkdir -p /tmp/backupdir
       	if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device, exiting...${N}"; fi
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
	initctl stop tcsd >/dev/null 2>&1
	tpmc clear
	tpmc def 0x100a 0x28 0x12000
	tpmc write 0x100a 76 28 10 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	device_management_client --action=remove_firmware_management_parameters
	device_management_client --action=set_firmware_management_parameters --flags=0x0
	# we do this to *ensure* that FWMP is gone even if device_management_client is bugging out
	
	if [[ $DEVFW != 1 ]]; then
		# flash gbb flags, devkeys, and set dev_firmware to 1 to prevent accidental reflashing :3
		/usr/share/vboot/bin/set_gbb_flags.sh 0xa0b1 || futility gbb -s --flash --flags=0xa0b1
  	if [[ $userkeys == "false" ]]; then
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
	doubleecho "This requires write protection to be disabled, and it will be checked before this script attempts anything"
  doubleecho "Checking for Firmware Write Protection..."
	checkWP

	echo -e "Are you sure you want to flash DevFW firmware?"
	askConfirmation

	echo -e "Getting backup selection..."
	selectBackup

  echo -e "Backup selection complete, flashing DevFW..."
  flashDevFW

	echo -e "If everything succeeded, you are now running DevFW!"
  echo -e "It is highly recommended to go backup the firmware that is now in your selected drive (or directory) to the cloud, or another safe place."
  echo -e "Whenever you're ready, enter recovery and plug in your modmium usb!"
}

clear
main
