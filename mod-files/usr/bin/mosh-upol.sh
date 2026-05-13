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

# -- policy flags --
DEVINSTALL_FILE="/mnt/stateful_partition/.devinstall_complete"
POLTEST_FILE="/mnt/stateful_partition/.policytesttool_setup"
POLICYFILE="/root/policy.json"

# -- FUNCTIONS --

install(){
	runscript "bash /root/policy.sh"
}
reinstall(){
	runscript "bash /root/policy.sh --reinstall"
}

grabpolicy(){
    as_system "cp $(ls -t /home/user/*/MyFiles/Downloads/policies-* | head -n 1) /root/policy.json"
    echo -e "Grabbing policy.json..."
    sleep 1
    echo -e "Done!"
    sleep 0.5
    menu_reset
    full_menu
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
    menuText="\nMOSH user policy editor\n"
	if [[ -f $DEVINSTALL_FILE || -f $POLTEST_FILE ]]; then
        options=("Run Policy Editor (Install)" "Reinstall" "Exit")
        functions=("install" "reinstall" "quit")
    else
        options=("Run Policy Editor (Install)" "Exit")
        functions=("install" "quit")
    fi
    if [[ ! -f $POLICYFILE ]]; then
        options=("Grab policy.json from downloads" "Exit")
        functions=("grabpolicy" "quit")
        menuText="\nMOSH user policy editor\n\n${R}PLEASE LOGIN TO YOUR ACCOUNT, GO TO ${N}chrome://policy${R} AND SAVE IT TO THE ROOT OF YOUR DOWNLOADS FOLDER.\n${N}After that, run 'Grab policy.json from downloads', then remove the account (or powerwash)."
    fi
	num_options=${#options[@]}
}

milestone
menu_reset
clear
full_menu
tput cnorm
selector