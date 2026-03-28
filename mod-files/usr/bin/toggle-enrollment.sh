#!/bin/bash
# written by mariah carey
# using qs for 142- suggested by xz8f

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
	echo -e "$1"
	sleep 3
	exit 1
}

if [[ -f /.deprovision ]]; then
	echo -e "${B}Currently unenrolled, enable enrollment? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm /.deprovision
		fail "${G}Done! Powerwash to re-enroll...${N}"
	else
		fail "${R}Exiting...${N}"
	fi
else
	echo -e "${B}Currently enrolled, enable unenrollment? [y/N]${N}"
	read -re
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo $(grep MILESTONE /etc/lsb-release | sed 's|^.*=||g') >/.deprovision
		fail "${G}Done! Powerwash to unenroll...${N}"
	else
		fail "${R}Exiting...${N}"
	fi
fi

fail "${R}How did you get here..?${N}"
