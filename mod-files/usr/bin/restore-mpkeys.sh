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
  futility gbb -s --flash --recoverykey="/root/.recoverykeys/$board.vbpubk"
  echo -e "Would you like to be unkeyrolled permanently? [y/N]"
  echo -e "${R}This will prevent you from reflashing devkeys until you re-disable FWWP fully${N}"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    flashrom --wp-range 0,0 || flashrom --wp-range 0 0
    flashrom --wp-enable
  fi
}

main(){
  clear
  checkWP
  echo -e "${R}This will update your firmware and revert your chromebook to stock keys (undoing developer firmware changes), are you ${UN}sure${RUN} you want to continue?${N} [y/N]"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "Restoring MPkeys, ${G}please connect your device to power (if you haven't already)${N}"
    sleep 2
    echo -e "Preparing for restore..."
    flashrom -r /pre-restorefw.rom > /dev/null 2>&1 # backup the fw in case something fails
    echo -e "Restoring firmware, ${R}DO NOT turn off your device${N}!"
    echo -e "This may take a while..."
    # before you think about removing the weird backup, i put it there because the longer it takes the more time someone will have to realize they missed something (like their battery being low, or not plugged in)
    chromeos-firmwareupdate -m output &> /dev/null && rm -rf image.bin ec.bin
    futility gbb -gr reco.key bios.bin && futility gbb -gk root.key bios.bin
    futility gbb -sr reco.key --flash && futility gbb -sk root.key --flash
    echo -e "${G}Done!"
    if [[ $board =~ ^corsola|^dedede|^nissa ]]; then
      echo -e "${B}Do you want to unkeyroll?"
      read -re
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        unkeyroll
      fi
    fi

    echo -e "Your device is now on MPkeys! Modmium will not boot after your device reboots, so please make sure you have a regular recovery image for [${UN}$board${RUN}] on hand."
    sleep 3
    fail "Exiting..."
  fi
  fail "Exiting..."
}

main
