#!/bin/bash
# written by fd21d69f9adc05e461ac
# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

mosh_gui_action shell.set changeShell 1 1 validateGuiShell
mosh_gui_state shell string "$(basename "${shell:-bash}")"
mosh_gui_metadata_done
mosh_gui_state_done
if [[ -d /usr/local/nix/store ]]; then
  if ! mountpoint -q /nix; then
    sudo mkdir -p /nix
    sudo mount --bind /usr/local/nix /nix
  fi
  source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  unset LD_LIBRARY_PATH
fi

# -- MAIN SCRIPT --
tput civis # :whale:

fail(){
  echo -e "$1"
  sleep 3
  exit 1
}

validateGuiShell() {
  mosh_gui_is_shell "$(mosh_gui_arg 0)"
}

changeShell(){
  tput cnorm
  stty echo
  echo -ne "\nEnter the name of your preferred shell: "
  read -rep '' shellPref
  tput civis
  stty -echo
  if ! which $shellPref &>/dev/null; then
    fail "${R}Could not find ${shellPref}, exiting...${N}"
  else
    echo -e "${G}${shellPref} found at $(which ${shellPref})${N}"
    echo -e "${Y}Setting shell...${N}"
    sleep 0.4
    which ${shellPref} > $shellfile
    echo -e "${G}Done!${N}"
    sleep 2.5
    exit
  fi
}

menu_reset(){
  options=("Change Shell" "Go Back")
  functions=("changeShell" "quit")
  num_options=${#options[@]}
  menuText=$(cat <<EOF
\nYour current shell is ${B}$(basename ${shell:-bash})${N}
You can change what shell will be used for root in this menu.
Ensure the shell is in \$PATH (nix-installed shells are supported).\n
EOF
  )
  num_options=${#options[@]}
}

mosh_gui_dispatch
menu_reset
clear
full_menu
tput cnorm
selector
