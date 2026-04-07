#!/bin/bash
# written by mariah carey & dmd
# using qs for 142- suggested by xz8f


# TODO: add powerwashing to MOSH for use with this by skids (any maybe a prompt in here too(?))

# colors
B='\033[38;5;45m'
G='\033[38;5;46m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
P='\033[38;5;135m'
N='\033[0m'
D='\033[1;90m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline




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

if [[ -f /.deprovision ]]; then
	echo -e "${B}You are currently ${R}unenrolled${B}, would you like to toggle [${G}allow${B}] enrollment? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm /.deprovision
		fail "${G}Done! Powerwash to re-enroll...${N}"
	else
		fail # :whale:
	fi
else
	echo -e "${B}You are currently ${G}enrolled${B}, would you like to toggle [${R}prevent${B}] enrollment? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo $(grep MILESTONE /etc/lsb-release | sed 's|^.*=||g') >/.deprovision
		fail "${G}Done! You will now be unenrolled on your next powerwash.${N}"
	else
		fail # :whale:
	fi
fi

fail "${R}How did you get here..?${N}"
