#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo 
. /usr/lib/libmosh.sh

# -- FUNCTIONS --

modsplash(){
	runscript "bash /usr/bin/modify-bootsplash.sh"
}
toggleEnrollment(){
	runscript "bash /usr/bin/toggle-enrollment.sh"
}
cr3nroll(){
	runscript "bash /usr/bin/cr3nroll.sh"
}
erevert(){
	runscript "bash /usr/bin/emergencyrevert.sh"
}
prenix(){
	runscript /usr/bin/nix-preinstall.sh
}

# -- MAIN SCRIPT --
tput civis # :whale:
milestone

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
