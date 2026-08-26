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

  while IFS='|' read -r path name || [[ -n "$path" ]]; do
    [[ "$path" =~ ^#.* ]] || [[ -z "$path" ]] && continue
    path=$(echo "$path" | xargs)
    name=$(echo "$name" | xargs)
    [[ -z "$path" ]] && continue
    paths+=("$path")
    options+=("$name")
  done < /usr/local/config/apps.conf

  num_options=${#options[@]}
  selected_index=0
  menuText=""
  if [[ " ${options[*]} " == *" Edit apps.conf "* ]]; then
    menuText="\nINFO: You can add up to 9 apps (or scripts) to this menu by editing '/usr/local/config/apps.conf'\n(The formatting is 'COMMAND | NAME' on each line)"
  fi
  if [[ $num_options -gt 9 ]]; then
    clear
    cat <<EOF | xargs -0 echo -ne
${R}Error: More than 9 apps added! ${N}
INFO: You can only add a ${B}maximum of 9 apps${N} to '/usr/local/config/apps.conf'!
EOF
    sleep 1
    echo -e "Returning to MOSH..."
    sleep 3
    exit 0
  fi
}

# menu_reset is the standard libmosh entry point (called by full_menu when it
# needs to redraw), so define it in terms of index() instead of duplicating
# libmosh's own full_menu/display_menu here.
menu_reset() {
  index
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
menu_reset
full_menu
tput cnorm
