#!/bin/bash

# this is a modified version of MOSH 

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

main() { 
  logo
  sleep 0.1
	echo ""
  echo -e "This requires write protection to be disabled, and it will be checked before this script attempts anything"
  echo ""
	sleep 0.5
	echo -e "Checking for Firmware Write Protection..."
	writeprotect=$(flashrom --wp-status 2>&1 | grep "disabled")
	if [[ $writeprotect == *"disabled"* ]]; then
		sleep 0.5
		echo -e "FWWP is currently ${R}DISABLED${N}, continuing..."
	else
		echo -e "FWWP is currently ${G}ENABLED${N}, checking for wp range..."
		wprange=$(flashrom --wp-status 2>&1 | grep -E "range: start=0x[0-9a-f]+, len=0x00000000")
		sleep 0.5
		if [[ $wprange != "" ]]; then
			echo -e "WP range is set to 0,0 you must fully disable FWWP before continuing."
			sleep 1
			exit 1
		else
			echo -e "WP range is still set, please disable your FWWP by following this guide: ${G}https://crosmium.dev/FWWP${N}"
			sleep 1
			exit 1
		fi
	fi

	device_management_client --action=remove_firmware_management_parameters 
	device_management_client --action=set_firmware_management_parameters --flags=0x0000 # just in case

	echo -e "Are you sure you want to flash DevFW firmware?"
	read -r -n 2 -s -p "Double click y to continue, or hold any other key to quit." confirmation # don't put Y if confirm wants y
    if [[ "$confirmation" != "yy" ]]; then
        echo -e "Denied! exiting.."
				exit 0
    fi
		
		echo -e "Removing rootfs verification (to save 5 minutes when installing modmium)..."
		# we make_dev_ssd to save 5 minutes on recovery
		/usr/share/vboot/bin/make_dev_ssd.sh --force >/dev/null 2>&1

		echo -e "Would you like to ${R}ERASE${N} an external (D)rive and backup to it, or backup to a directory? (D = drive, P = directory)"
    echo -e "Backing up to a (D)rive is highly recommended, but if you know what you're doing, [or already have a mount (P)oint], you can use a directory"
		read -ep "(D/P): " resp 
    if [[ $resp =~ ^[Dd]$ ]]; then
        echo -e "These are the drives connected to your device:"
        lsblk -dpno NAME,SIZE,MODEL | grep "/dev/sd"
        echo -e "What drive would you like write the backup onto? (THIS WILL ERASE THE DRIVE!!!!)"
        read -ep "Drive: " driveloc
        driveloc="${driveloc%/}"
        if [[ $driveloc == *"/dev/"* ]]; then
            mkfs.vfat -F 32 $driveloc
            mkdir /tmp/backupdir
            mount $driveloc /tmp/backupdir
        else
            mkfs.vfat -F 32 /dev/$driveloc
            mkdir /tmp/backupdir
            mount /dev/$driveloc /tmp/backupdir
        fi
        DRIVEBACKUP=1
        sync
        BACKUPDIR=/tmp/backupdir
				[ -d ${BACKUPDIR} ] && touch ${BACKUPDIR}/.test || (echo "unable to write to backup" && exit 1) # exits if isn't writable (this is redundant but i am paranoid)
		elif [[ $resp =~ ^[Pp]$ ]]; then
    		echo -e "What directory would you like to backup to?"
    		read -p "Dir: " BACKUPDIR
    		[ -d ${BACKUPDIR} ] && touch ${BACKUPDIR}/.test || (echo "unable to write to backup" && exit 1) # exits if backup doesn't exist or isn't writable
    		echo -e "Valid directory!"
		else
				echo "Invalid response, exiting..." && exit 1
		fi
    sleep 1
    echo -e "Backup selection complete, flashing DevFW..."
    sleep 0.5
    DEVFW=$(vpd -i RO_VPD -g "dev_firmware")
    if [[ $DEVFW != 1 ]]; then
		# flash gbb flags, devkeys, and set dev_firmware to 1 to prevent accidental reflashing :3
		/usr/share/vboot/bin/set_gbb_flags.sh 0x80b1 || futility gbb -s --flash --flags=0x80b1
        /usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid --backup_dir $BACKUPDIR
        sync # sync because I dont trust ChromeOS
        vpd -i RO_VPD -s "dev_firmware"=1
    else 
      echo -e "You are already using DevFW (Devkeys)! cancelling"
      exit 1
    fi
    sleep 0.5
    if [[ $DRIVEBACKUP == 1 ]]; then
    	umount /tmp/backupdir
    fi
    echo -e "If everything succeeded, you are now running DevFW!"
    echo -e "It is highly recommended to go backup the firmware that is now in your selected drive (or directory) to the cloud, or another safe place."
    echo -e "Rebooting in 10 seconds, hit Ctrl+C to cancel..."
    sleep 10
    reboot
}

clear
main
