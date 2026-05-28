#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- FUNCTIONS --

modsplash(){
	runscript /usr/bin/modify-bootsplash.sh
}
toggleEnrollment(){
	runscript /usr/bin/toggle-enrollment.sh
}
cr3nroll(){
	runscript /usr/bin/cr3nroll.sh
}
erevert(){
	runscript /usr/bin/emergency-revert.sh
}
prenix(){
	runscript /usr/bin/nix-preinstall.sh
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
	options=("Modify Bootsplash" "Toggle Enrollment" "Open Cr3nroll" "${R}Emergency Revert${N}" "Install Nix" "Go back")
	functions=("modsplash" "toggleEnrollment" "cr3nroll" "erevert" "prenix" "quit")
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
