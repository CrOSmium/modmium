#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh
MARKER="/usr/local/.nix_install_done"

# -- MAIN SCRIPT --
tput civis # :whale:

installNix(){
  runscript /usr/bin/.nix-install.sh
}

mixupd(){
  echo -e "Updating mix..."
  sudo cp /usr/bin/.mix /usr/bin/mix
  sleep 1
  echo -e "Done!"
  sleep 0.6
}

updateMix(){
  runscriptnoroot mixupd
}

menu_reset(){
  if [[ -f $MARKER ]]; then
  options=("Install Nix" "Update ${G}Mix${N}" "Go Back")
  functions=("installNix" "updateMix" "quit")
  else
  options=("Install Nix" "Go Back")
  functions=("installNix" "quit")
  fi
  num_options=${#options[@]}
  menuText=$(cat <<EOF
This will install 'Nix', A package manager usable on Modmium, ${R}Not recommended unless you know what you're doing.${N}
You can use '${B}mix${N} [arg]' (a command wrapper) in a root shell to use Nix like a regular package manager like apt if you're lazy.\n
EOF
  )
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
