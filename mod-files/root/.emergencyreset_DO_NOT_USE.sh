#!/bin/bash
# written by dmd, this is a WIP

B='\033[38;5;45m'
G='\033[38;5;46m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
P='\033[38;5;135m'
N='\033[0m'
D='\033[1;90m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline
board=$(grep -F "RELEASE_BOARD" /etc/lsb-release | sed 's/^.*=//' | sed 's/-.*^*//')

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root. You can do so by using 'sudo -i'."
    exit 1
fi
fail(){
	echo -e "$1"
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

main(){
echo -e "Firmware write protection is [${R}disabled${N}], continuing..."
echo -e "This script is a work in progress, it should return you to MPkeys and restore your firmware to normal  you lost your backup, however, it is very destructive and can brick your device."
echo -e "${R}This will update your firmware and possibly re-keyroll you, are you ${UN}sure${RUN} you want to continue?${N} [y/N]"
read -re
if [[ $REPLY =~ ^[Yy]$ ]]; then
chromeos-firmwareupdate --mode=factory --force --gbb_flags=0xa0b1
vpd -i RW_VPD -d "dev_firmware" # factory fwupdate should wipe this, but just in case
# TODO (dmd): add auto unkeyrolling & ask to permanently prevent keyrolling (im implementing this soon)
fi
}

main
