#!/bin/bash
# written by mariah carey & DMD
# using qs for 142- suggested by xz8f

# TODO: rewrite to fit the rest of MOSH's UI

source /usr/lib/libmosh.sh

fail() {
	if [[ "$1" == "" ]]; then
		echo -e "Exiting..."
		sleep 3
		exit 1
	else
		echo -e "$1"
		sleep 0.75
		echo -e "Exiting..."
		sleep 2.25
		exit 1
	fi
}

promptPowerwash(){
	echo -e "${Y}Would you like to powerwash now? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "fast safe keepimg" > /mnt/stateful_partition/factory_install_reset
		echo -e "${G}Done! Rebooting...${N}"
		sleep 1
		reboot
	else
		fail # :whale:
	fi
}

if [[ -f /.deprovision ]]; then
	echo -e "${B}You are currently ${R}unenrolled${B}, would you like to toggle [${G}allow${B}] enrollment? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm /.deprovision
		echo -e "${G}Done!${N}"
		promptPowerwash
	else
		fail # :whale:
	fi
else
	echo -e "${B}You are currently ${G}enrolled${B}, would you like to toggle [${R}prevent${B}] enrollment? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo $(grep MILESTONE /etc/lsb-release | sed 's|^.*=||g') >/.deprovision
		echo -e "${G}Done!${N}"
		promptPowerwash
	else
		fail # :whale:
	fi
fi

fail "${R}How did you get here..?${N}"
