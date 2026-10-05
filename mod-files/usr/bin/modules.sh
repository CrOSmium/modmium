#!/bin/bash
# written by DMD


# -- Pre TUI init --
stty -echo
echo -ne "\033]0;Modules\007"
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
  source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  unset LD_LIBRARY_PATH
fi

# -- FUNCTIONS --

core(){
  echo "core"
  sleep 1
  menu_reset
  full_menu
}

featured(){
  echo "featured"
  sleep 1
  menu_reset
  full_menu
}

remote(){
  echo "remote"
  sleep 1
  menu_reset
  full_menu
}

# -- MAIN SCRIPT --
tput civis # :whale:
menu_reset() {
  options=("TBD" "TBD" "TBD" "Exit")
  functions=("core" "featured" "remote" "quit")
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
