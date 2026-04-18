#!/bin/bash

# written by DMD


# -- Pre TUI init --
stty -echo 
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:
milestone

menu_reset() {
	options=("1) Modify Bootsplash" "2) Toggle Enrollment" "3) Open Cr3nroll" "4) ${R}Emergency Revert${N}" "5) Install Nix" "6) Go back")
    num_options=${#options[@]}
}
menu_reset

selector() {
	sel="${options[$selected_index]}"

	case "$sel" in
		1*)
			runscript "bash /usr/bin/modify-bootsplash.sh"
			;;
		2*)
			runscript "bash /usr/bin/toggle-enrollment.sh"
			;;
    3*)
        runscript "bash /usr/bin/cr3nroll.sh"
        ;;
    4*)
        runscript "bash /usr/bin/emergencyrevert.sh"
        ;;
    5*)
        exec /usr/bin/nix-preinstall.sh
        ;;
	6*)
		stty echo
		tput cnorm
		clear
		exec /usr/bin/crosh
	esac
}
clear
full_menu
tput cnorm
selector
