#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:
milestone

installNix(){
	runscript /usr/bin/.nix-install.sh
}

menu_reset(){
	options=("Install Nix" "Go Back")
	functions=("installNix" "quit")
	num_options=${#options[@]}
	menuText="This will install 'Nix', A package manager usable on Modmium, ${R}Not recommended unless you know what you're doing.${N}\nYou can use '${B}mix${N} [arg]' in a root shell to use Nix like a regular package manager like apt, or if you're just lazy.\n"
	num_options=${#options[@]}
}

milestone
menu_reset
clear
full_menu
tput cnorm
selector
