#!/bin/bash
# similarly to ext.sh, this too had to be its own file

B='\033[1;36m'
G='\033[1;32m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'
D='\033[1;90m'

menu_logo() {
    echo -ne "\033]0;MOSH\007"
    echo -e "Welcome to MOSH, the Modmium developer shell

If you got here by mistake, don't panic! Just close this tab and carry on.

This shell contains a list of utilities for performing various actions on a chromebook running Modmium.
"
}

fail() {
	echo -e "$1"
	sleep 3
	exit 1
}

dropModFiles() {
	modFiles=$(find /mnt/stateful_partition/git/modmium/mod-files -mindepth 1 -name "*")
	for file in $modFiles; do
		echo $file # debugging
		if [[ -d $file ]]; then
			:
		elif [[ -f $file ]]; then
			realFile=$(echo "$file" | sed 's/^.*mod-files//')
			echo $realFile
			mkdir -p $(dirname $realFile)
			cp $file $realFile
			chown 0:0 $realFile
			chmod 777 $realFile
		fi
	done
}

update() {
	clear
	menu_logo
	source /root/.bashrc # just in case, so we know git https will work
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	git clone git@github.com:crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}" 
	# we use ssh for now since the repo is private, REPLACE WITH HTTPS LATER
	echo -e "${G}Successfully cloned repository!${N} Dropping new files..." 
	dropModFiles || fail "${R}Failed to drop updated files, please make an issue report on https://github.com/crosmium/modmium with details of any changes you made if applicable...${N}"
	echo -e "${G}Done! Cleaning up...${N}"
	rm -rf /mnt/stateful_partition/git/modmium
	sleep 10 
	return
}

update
