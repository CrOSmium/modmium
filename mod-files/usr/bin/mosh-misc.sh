#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo 
. /usr/lib/libmosh.sh
. /usr/lib/mosh-functions.sh

# -- MAIN SCRIPT --
tput civis # :whale:
milestone

menu_reset() {
	options=("Modify Bootsplash" "Toggle Enrollment" "Open Cr3nroll" "${R}Emergency Revert${N}" "Install Nix" "Go back")
	functions=("modsplash" "toggleEnrollment" "cr3nroll" "erevert" "prenix" "return")
	num_options=${#options[@]}
}
menu_reset

selector() {
	for option in ${!options[@]}; do
		if [[ $selected_index == $option ]]; then
			${functions[$option]}
		fi
	done
}

clear
full_menu
tput cnorm
selector
