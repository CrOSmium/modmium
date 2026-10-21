#!/bin/bash
# written by DMD


vtmosh=0
for skid in "$@"; do
  if [[ "$skid" == "-v" ]]; then
    vtmosh=1
    break
  fi
done

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
  source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  unset LD_LIBRARY_PATH
fi

# -- FUNCTIONS --

device(){
  runscript /usr/bin/devpolicy-editor.sh
}

user(){
  runscript /usr/bin/mosh-upol.sh
}

dispolf(){
  if [[ $polsync -eq 1 ]]; then
    echo "--device-management-url=http://localhost:9999" >> /etc/chrome_dev.conf 
    echo -e "${R}Disabled${N} policy syncing!\n${D}THIS WILL BREAK ENROLLMENT, RE ENABLE SYNCING IF YOU NEED TO RE-ENROLL${N}"
    sleep 2
    echo -e "\nOnce again, please remember to ${UN}re-enable policy syncing when you need to re-enroll ${D}(or add a new account)${N}${RUN}, otherwise you will be 'unable to reach Google'.\nThis is your final reminder."
    sleep 3
    echo -e "\nRestarting ui..."
    sleep 2
    initctl restart ui
  else
    sed -i '/^[^#]*--device-management-url[=[:space:]]\+\S+/d' /etc/chrome_dev.conf
    echo -e "${G}Enabled${N} policy syncing!\n"
    sleep 1
    echo -e "Restarting ui..."
    sleep 2
    initctl restart ui
  fi
  sync
  exit 0
}

dispol(){
  employ dispolf
  menu_reset
  full_menu
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
  menuText="\nPolicies\n"
  if [[ $vtmosh -eq 1 ]]; then
    options=("${G}Device${N} Policy Editor" "${Y}User${N} Policy Editor")
    functions=("device" "user" "dispol" "quit")
  else
    options=("Device Policy Editor")
    functions=("device" "dispol" "quit")
  fi
  
  if grep -qE '^[^#]*--device-management-url(=|\s+)\S+' /etc/chrome_dev.conf; then
    polsync=0
    options+=("Re-Enable Policy Syncing" "Exit")
  else
    polsync=1
    options+=("Disable Policy Syncing" "Exit")
  fi
  
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
