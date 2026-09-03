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
owner=$(cat /usr/share/.gitowner)
repo=$(cat /usr/share/.gitrepo)
[[ ( -n $owner ) && ( -n $repo ) ]] && repository="https://github.com/${owner}/${repo}"
originalRepository="https://github.com/CrOSmium/modmium"

# -- MAIN SCRIPT --
tput civis # :whale:

fail(){
  echo -e "$1"
  sleep 3
  exit 1
}

parseUrl(){
  url=${1}

  url="${url#https://}"
  url="${url#http://}"

  url="${url/git@github.com:/github.com/}"

  url="${url%.git}"

  url="${url%/}"

  path="${url#*github.com/}"

  export owner="$(echo "$path" | cut -d'/' -f1)"
  export repo="$(echo "$path" | cut -d'/' -f2)"

  [[ -z "$owner" || -z "$repo" ]] && fail "${R}Could not parse owner/repo from ${1}${N}"
}

setRepo(){
  echo -e "${Y}Changing repository...${N}"
  echo "${owner}" >/usr/share/.gitowner
  echo "${repo}" >/usr/share/.gitrepo
  echo -e "${G}Done, you can use the updater to update to the repository you selected!${N}"
  sleep 3
  exit
}

changeRepo(){
  tput cnorm
  stty echo
  echo -e "${R}WARNING: Changing the source repository allows the owner of the repository to ${UN}execute any code${RUN} on this device.${N}\nBe ${R}certain${N} you trust the developers. Unless you own the repository yourself and are a developer, you should probably not use this. ${R}If you don't understand any of this, GO BACK NOW.${N}"
  echo -ne "Enter the URL to the repository: "
  read -re URL

  url="${URL:?EMPTY}"
  if [[ $url == "EMPTY" ]]; then
    fail "${R}No URL inputted, exiting...${N}"
  fi

  parseUrl "${url}"
  echo -e "Is this correct? \n${B}Owner:${owner}\nRepo:${repo}${N} \n[Y/n]"
  read -re
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    fail "${R}Exiting...${N}"
  fi
  tput civis
  stty -echo
  setRepo
}

resetRepo(){
  tput cnorm
  stty echo
  echo -e "Would you like to ${B}reset${N} the source repository to the official Modmium (by CrOSmium)? [Y/n]"
  read -re
  if [[ $REPLY =~ ^[Nn] ]]; then
    fail "${R}Exiting...${N}"
  fi
  parseUrl "${originalRepository}"
  tput civis
  stty -echo
  setRepo
}

menu_reset(){
  options=("Change Source Repository" "Reset Repository" "Go Back")
  functions=("changeRepo" "resetRepo" "quit")
  num_options=${#options[@]}
  menuText=$(cat <<EOF
Your current repository is ${B}${repository:-$originalRepository}${N}
You can change what repository will be used for updating Modmium.
EOF
  )
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
