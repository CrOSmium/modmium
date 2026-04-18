#!/bin/bash

# written by DMD

# -- Pre TUI init --
stty -echo 
source /usr/lib/libmosh.sh


# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
	options=("1) Full factory revert [restore OS & MPkeys]" "2) Revert lost MPkeys" "3) Go back")
    num_options=${#options[@]}
}

milestone
menu_reset

selector() {
	sel="${options[$selected_index]}"

	case "$sel" in
		1*)
			echo -e "This option does not exist yet, but the basics for it will be:\n1. Restore MPkeys (either from backup or with restore_mpkeys.sh\n2. Recover ChromeOS\n3. ask if the user wants to keep the gbb flags as 0xa0b1 or restore them to 0x0"
            echo -e "this will exit in 5 seconds :3" 
            sleep 5
			;;
        2*)
            runscript "bash /usr/bin/restore-mpkeys.sh"
            ;;
		3*)
			stty echo
			tput cnorm
			clear
			exit 0
	esac
}
menu_logo() {
	echo -ne "\033]0;MOSH\007"
  echo -e "Welcome to MOSH, the Modmium developer shell

If you got here by mistake, don't panic! Just close this tab and carry on.

This shell contains a list of utilities for performing various actions on a chromebook running Modmium.

SPECIAL NOTE: 'Revert lost MPkeys' should only be used if you ${UN}${R}lost${RUN}${N} your backup and need to revert to factory.
"
}
clear
full_menu
tput cnorm
selector
