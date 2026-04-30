#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo 
source /usr/lib/libmosh.sh


# -- MAIN SCRIPT --
tput civis # :whale:

factoryReset(){
	cat <<EOF | xargs -0 echo -ne
This option does not exist yet, but the basics for it will be:
1. Restore MPkeys (either from backup or with restore-mpkeys.sh
2. Recovery ChromeOS
3. Ask if the user wants to keep gbb flags are 0xa0b1 or restore them to 0x0 to pass aprov
This will exit in 5 seconds :3
EOF
	sleep 5
}
restoreMPkeys(){
	runscript /usr/bin/restore-mpkeys.sh
}
menu_reset() {
	options=("Full factory revert [restore OS & MPkeys]" "Revert lost MPkeys" "Go Back")
	functions=("factoryReset" "restoreMPkeys" "quit")
	num_options=${#options[@]}
	menuText="SPECIAL NOTE: 'Revert lost MPkeys' should only be used if you ${UN}${R}lost${RUN}${N} your backup and need to revert to factory."
	num_options=${#options[@]}
}

milestone
menu_reset
clear
full_menu
tput cnorm
selector
