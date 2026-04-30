#!/bin/bash
# created by DMD

source /usr/lib/libmosh.sh
board=$(grep -F "RELEASE_BOARD" /etc/lsb-release | sed 's/^.*=//' | sed 's/-.*^*//') # thanks mariah!

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root. You can do so by using 'sudo -i'."
    exit 1
fi

fail(){
	echo -e "$1"
	sleep 4
	exit 0
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

unkeyroll(){
    echo -e "You are currently ${R}keyrolled${N}, would you like to be unkeyrolled?\n(unkeyrolling breaks AP-RO verification) [y/N]"
    read -re
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        futility gbb -s --flash --recoverykey="/root/.recoverykeys/$board.vbpubk"
        echo -e "Would you like to be unkeyrolled permanently? [y/N]"
        echo -e "${R}This will prevent you from reflashing devkeys until you re-disable FWWP fully${N}"
        read -re
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            flashrom --wp-range 0,0 || flashrom --wp-range 0 0
            flashrom --wp-enable
			
        fi
    fi
}

main(){
    clear
    checkWP
    echo -e "This script is a work in progress, it should return you to MPkeys and restore your firmware to factory if you lost your backup."
    echo ""
	echo -e "${R}${UN}ONLY${RUN} use this if you lost your backup${N}, and need to revert to factory FW ${UN}at all costs${RUN}${N}"
    echo -e "${R}This will update your firmware and possibly re-keyroll you, are you ${UN}sure${RUN} you want to continue?${N} [y/N]"
    read -re
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${R}are you ${UN}really${RUN}, REALLY sure? ${N}[${R}y${N}/N]"
        read -re 
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "Restoring MPkeys, ${G}please connect your device to power (if you haven't already)${N}"
                sleep 2
				echo -e "Preparing for restore..."
				flashrom -r /pre-restorefw.rom > /dev/null 2>&1 # backup the fw in case something fails
                echo -e "Restoring firmware, ${R}DO NOT turn off your device${N}!"
				echo -e "This may take a while..."
				# before you think about removing the weird backup, i put it there because the longer it takes the more time someone will have to realize they missed something (like their battery being low, or not plugged in)
                chromeos-firmwareupdate --mode=factory --force > /dev/null 2>&1
                vpd -i RW_VPD -d "dev_firmware"
				echo -e "Firmware restore complete!"
                sleep 0.75
                echo -e "Do you want your device to be 'factory'? [y/N]\nThis means your device will pass APROV, but will be keyrolled (if it can be), and GBB flags will be 0x0.\n(if you press [N], the post restore will continue)"
				echo -e "Press [N] if you want to have the option to change your GBB flags and (or) unkeyroll now."
                read -re
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "Your device is now factory! Modmium will not boot after your device reboots, so please make sure you have a regular recovery image for [$board] on hand."
                    sleep 3
                    fail "Skipping unkeyroll/gbbflags and exiting..."
                else
                    echo -e "Do you want to set GBB flags to '0xa0b1' or leave them as default? [y/N]"
                    read -re
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        futility gbb -s --flash --flags=0xa0b1 || /usr/share/vboot/bin/set_gbb_flags.sh 0xa0b1
                    fi
                    if [[ "$board" == "dedede" || "$board" == "corsola" || "$board" == "nissa" ]]; then
                        unkeyroll
                    fi
                fi
            fi
            echo -e "Your device is now on MPkeys! Modmium will not boot after your device reboots, so please make sure you have a regular recovery image for [${UN}$board${RUN}] on hand."
            sleep 3
            fail "Exiting..."
    fi
    fail "Exiting..."
}

main
