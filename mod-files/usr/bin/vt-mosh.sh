#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh
if [[ -d /usr/local/nix/store ]]; then
	# issues can get caused if a user has a custom shell.
	# before, this code only ran if .bashrc was sourced,
	# but the shell wouldn't open if .bashrc wasn't sourced
	# chicken and egg. we fix it here.
	if ! mountpoint -q /nix; then
		sudo mkdir -p /nix
    sudo mount --bind /usr/local/nix /nix
	fi
	sudo . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
	unset LD_LIBRARY_PATH
fi

# -- FUNCTIONS --

rootsh(){
	runscript "sudo -i -u root"
}
chronosh(){
	runscript "sudo -i -u chronos"
}
update(){
	runscript /usr/bin/update-modmium.sh
}
devpol(){
	runscript /usr/bin/devpolicy-editor.sh
}
userpol(){
    runscript /usr/bin/mosh-upol.sh
}
misc(){
	runscript /usr/bin/mosh-misc.sh
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
    menuText="\n${D}If you'd like skip this menu by default, run 'touch /usr/local/.defaultvt'${N}\n"
	options=("Root Shell" "Chronos Shell" "Update Modmium [NOT CHROMEOS]" "Edit ${Y}Device Policies${N}" "Edit ${G}User Policies${N}" "Misc" "Exit")
	functions=("rootsh" "chronosh" "update" "devpol" "userpol" "misc" "quit")
	num_options=${#options[@]}
}

milestone
menu_reset
clear
full_menu
tput cnorm
selector
