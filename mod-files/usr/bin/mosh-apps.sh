#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:

if [[ ! -f /usr/local/config/apps.conf ]]; then
  as_system mkdir -p /usr/local/config
  as_system "cp /root/.mosh-apps-template /usr/local/config/apps.conf"
fi

index() {
  paths=()
  options=()
  if [[ $nopt == 1 ]];then
    menuText="\nINFO: You can add up to 9 apps (or scripts) to this menu by editing '/usr/local/config/apps.conf'\n(The formatting is 'COMMAND | NAME' on each line)"
  fi
  while IFS='|' read -r path name || [[ -n "$path" ]]; do
    [[ "$path" =~ ^#.* ]] || [[ -z "$path" ]] && continue
    path=$(echo "$path" | xargs)
    name=$(echo "$name" | xargs)
    [[ -z "$path" ]] && continue
    paths+=("$path")
    display_num=$(( ${#paths[@]} ))
    options+=("$name")
  done < /usr/local/config/apps.conf

  num_options=${#options[@]}
  selected_index=0
  if [[ " ${options[*]} " == *" Edit apps.conf "* ]]; then
    nopt=1
  fi
}

selector() {
  torun="${paths[$selected_index]}"
  if [[ -z "$torun" ]]; then
    return
  fi
  case "$torun" in
    *"exit 0")
      exit 0
      ;;
    *)
      runscript "$torun"
      ;;
  esac
}

clear
index
full_menu
tput cnorm
selector
