#!/bin/bash
# written by fd21d69f9adc05e461ac
# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh
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

changeShell(){
  tput cnorm
  stty echo
  echo -ne "Enter the name of your preferred shell: "
  read -rep '' shellPref
  tput civis
  stty -echo
  if ! which $shellPref &>/dev/null; then
    fail "${R}Could not find ${shellPref}, exiting...${N}"
  else
    echo -e "${G}${shellPref} found at $(which ${shellPref})${N}"
    echo -e "${Y}Setting shell...${N}"
    which ${shellPref} > $shellfile
    echo -e "${G}Done!${N}"
    sleep 3
    exit
  fi
}

menu_reset(){
  options=("Change Shell" "Go Back")
  functions=("changeShell" "quit")
  num_options=${#options[@]}
  menuText=$(cat <<EOF
Your current shell is ${B}$(basename ${shell:-bash})${N}
You can change what shell will be used for root in this menu.
Ensure the shell is in \$PATH (nix-installed shells are supported).
EOF
  )
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
