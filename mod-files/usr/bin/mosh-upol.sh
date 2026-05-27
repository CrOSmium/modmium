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
  echo -e "Grabbing policy.json..."
  sleep 0.4
  policy=$(find /home/user/*/MyFiles/Downloads/ -name "policies_*" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d" " -f2-)
  [[ -z "$policy" ]] && echo -e "No policy file found, are you sure it's in Downloads?" >&2
  sudo cp -- "$policy" /root/policy.json > /dev/null 2>&1
  sleep 1
  echo -e "Refreshing menu..."
  sleep 0.5
  menu_reset
  full_menu
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_logo() {
  echo -e "Welcome to VT-MOSH, the Modmium developer console.\n\nIf you got here by mistake, don't panic! Just press exit, then Ctrl+Alt+F1 [usually the back arrow] and carry on.\n\nThis console contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
}

menu_reset() {
  menuText="\nPolicy Test Tool [User Policy Editor]\n${D}[Please note that this will set your policies to the recommended defaults for Modmium,\nif you'd like to edit them, they can be found in '${N}/usr/local/share/policy-test-tool/policies.json${D}']${N}\n"
  if [[ -f $DEVINSTALL_FILE || -f $POLTEST_FILE ]]; then
    options=("Run Policy Editor (Install)" "Update policy.json [from downloads]" "Reinstall" "Exit")
    functions=("install" "grabpolicy" "reinstall" "quit")
  else
    options=("Run Policy Editor (Install)" "Update policy.json [from downloads]" "Exit")
    functions=("install" "grabpolicy" "quit")
  fi
  if [[ ! -f $POLICYFILE ]]; then
    options=("Grab policy.json from downloads" "Exit")
    functions=("grabpolicy" "quit")
    menuText="\nMOSH user policy editor\n\n${R}PLEASE LOGIN TO YOUR ACCOUNT, GO TO ${N}chrome://policy${R} AND SAVE IT TO THE ROOT OF YOUR DOWNLOADS FOLDER.\n${N}After that, run 'Grab policy.json from downloads', then remove the account (or powerwash)."
  fi
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
