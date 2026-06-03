#!/bin/bash
# written by DMD

# -- LOGIN PROMPT --
passwd="$(sudo cat /mnt/stateful_partition/etc/mosh.passwd 2>/dev/null)"
if [[ "$passwd" ]]; then
  hash=$(echo "$passwd" | cut -d: -f2)
  trap "" SIGINT
  stty -echo
  echo -e "\nVT-MOSH has been locked with a password, please enter it below."
  echo -ne "Enter VT-MOSH password: "
  read -r auth
  stty echo
  echo ""
  salt=$(echo "$hash" | cut -d'$' -f3)
  hashin=$(openssl passwd -1 -salt "$salt" "$auth")
  if [[ "$hashin" != "$hash" ]]; then
    echo -e "Incorrect password. Access denied."
    sleep "$(awk 'BEGIN {srand(); printf "%.2f", 0.6 + (rand() * 0.4)}')" # tuff random sleep to make brute forcing harder
    echo -e "Exiting.."
    exit 1
  else
    echo -e "Login successful!"
    trap - SIGINT
    sleep 0.67
  fi
fi

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
	sudo source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
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
apps(){
	runscript /usr/bin/mosh-apps.sh
}
# -- MAIN SCRIPT --
tput civis # :whale:

menu_logo() {
	echo -e "Welcome to VT-MOSH, the Modmium developer console.\n\nIf you got here by mistake, don't panic! Just press exit, then Ctrl+Alt+F1 [usually the back arrow] and carry on.\n\nThis console contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
}

menu_reset() {
    menuText="\n${D}If you'd like skip this menu by default, run 'touch /usr/local/.defaultvt'${N}\n"
	options=("Root Shell" "Chronos Shell" "Manage Modmium" "Edit ${Y}Device Policies${N}" "Edit ${G}User Policies${N}" "Apps" "Misc" "Exit")
	functions=("rootsh" "chronosh" "update" "devpol" "userpol" "apps" "misc" "quit")
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
