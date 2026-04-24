#!/bin/bash

# written by DMD


# -- Pre TUI init --
stty -echo 
. /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:
milestone

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
        display_num=$(( ${#paths[@]} ))
        options+=("$display_num) $name")
    done < /usr/local/config/apps.conf

    num_options=${#options[@]}
    selected_index=0
    if [[ " ${options[*]} " == *" Edit apps.conf "* ]]; then
        nopt=1
    fi
    if [[ $num_options -gt 9 ]]; then
        clear
        echo -e "${R}Error: More than 9 apps added! ${N}"
        echo -e "INFO: You can only add a ${B}maximum of 9 apps${N} to '/usr/local/config/apps.conf'!"
        sleep 1
        echo -e "Returning to MOSH..."
        sleep 3
        exec /usr/bin/crosh
    fi
}
index

selector() {
    torun="${paths[$selected_index]}"

    if [[ -z "$torun" ]]; then
        return
    fi

    case "$torun" in
        *crosh)
            exec /usr/bin/crosh
            ;;
        *)
            runscript "$torun"
            ;;
    esac
}


full_menu() {
  clear
	stty -echo
  tput civis
  while true; do
		display_menu
    read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
    	read -rsn2 -t 1 keyseq
      case "$keyseq" in
        '[A')
          selected_index=$(((selected_index - 1 + num_options) % num_options))
          ;;
        '[B')
          selected_index=$(((selected_index + 1) % num_options))
          ;;
      esac
    elif [[ "$key" =~ [1-9] ]]; then
    	target_index=$((key - 1))
      if [ "$target_index" -lt "$num_options" ]; then
        selected_index=$target_index
      fi
    elif [[ "$key" == "" ]]; then
    	break
    fi
  	tput rc
  done
  selector
}
display_menu() {
	tput sc
  menu_logo

  if [[ "$MILESTONE" == "" ]]; then
  	echo -e "${R}Uhh... how are you seeing this if ChromeOS isn't installed..?${N}"
  elif [[ "$MILESTONE" -le 131 ]]; then
    echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N}, which is not officially supported by Modmium."
  elif [[ "$STABLEVERSIONS" =~ (^|,)"$MILESTONE"(,|$) ]]; then
  	echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} (Modmium-${branch}) --"
  else
    echo -e "-- You are currently on ChromeOS ${R}v$MILESTONE${N} (Modmium-${branch}-${R}untested${N}) -- [This version hasn't been tested by the Modmium devs, but it will likely still work fine.]"
  fi
  if [[ $nopt == 1 ]];then
    echo -e "\nINFO: You can add up to 9 apps (or scripts) to this menu by editing '/usr/local/config/apps.conf'\n(The formatting is 'COMMAND | NAME' on each line)"
  fi
  echo ""
  for i in "${!options[@]}"; do
  	if [[ $i -eq $selected_index ]]; then
    	printf "\e[7m > ${options[$i]} \e[0m\n"
    else
    	printf "   ${options[$i]}      \n"
  	fi
  done
}
clear
full_menu
tput cnorm
selector
