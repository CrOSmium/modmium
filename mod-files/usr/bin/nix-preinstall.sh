#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:

installNix(){
	runscript /usr/bin/.nix-install.sh
}

menu_reset(){
	options=("Install Nix" "Go Back")
	functions=("installNix" "quit")
	num_options=${#options[@]}
	menuText=$(cat <<EOF
This will install 'Nix', A package manager usable on Modmium, ${R}Not recommended unless you know what you're doing.${N}
You can use '${B}mix${N} [arg]' (a command wrapper) in a root shell to use Nix like a regular package manager like apt if you're lazy.
EOF
	)
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
