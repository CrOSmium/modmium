#!/bin/bash

# written by DMD

STABLEVERSIONS=$(cat /root/.stable_versions.txt) # just add a version to this file if you tested it and it has no issues
source /usr/share/misc/shflags

# -- Root escalation --
as_system() {
	sudo $@
}

# -- { DO NOT MODIFY } --
selected_index=0
branch=$(cat /.branch)
# -----------------------

# TUI colors :D
B=$'\033[38;5;45m'
G=$'\033[38;5;46m'
Y=$'\033[38;5;220m'
R=$'\033[38;5;203m'
P=$'\033[38;5;135m'
N=$'\033[0m'
D=$'\033[1;90m'
UN=$'\033[4m' #underline
RUN=$'\033[24m' #reset underline
MILESTONE=$(grep MILESTONE /etc/lsb-release | cut -d= -f2 | tr -d '\r')


milestone(){ 
	return # :whale:
}

# STOLEN CODE FROM BR0KER TO GET MILESTONE :3
get_largest_cros_blockdev() {
  local largest size dev_name tmp_size remo
  size=0
  command -v sfdisk >/dev/null 2>&1 || command return 0
  for blockdev in /sys/block/*; do
  	dev_name="${blockdev##*/}"
    echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
    tmp_size=$(cat "$blockdev"/size)
    remo=$(cat "$blockdev"/removable)
    if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
      case "$(sfdisk -d "/dev/$dev_name" 2>/dev/null)" in
      	*'name="STATE"'*'name="KERN-A"'*'name="ROOT-A"'*)
          largest="/dev/$dev_name"
          size="$tmp_size"
          ;;
      esac
  	fi
  done
  echo "$largest"
}

format_part_number() {
  echo -n "$1"
  echo "$1" | grep -q '[0-9]$' && echo -n p
  echo "$2"
}
get_fixed_dst_drive() {
	local dev
  if [ -z "${DEFAULT_ROOTDEV}" ]; then
  	for dev in /sys/block/sd* /sys/block/mmcblk*; do
    	if [ ! -d "${dev}" ] || [ "$(cat "${dev}/removable")" = 1 ] || [ "$(cat "${dev}/size")" -lt 2097152 ]; then
      	continue
      fi
      if [ -f "${dev}/device/type" ]; then
      	case "$(cat "${dev}/device/type")" in
        	SD*)
            continue
          	;;
        esac
      fi
    	DEFAULT_ROOTDEV="{$dev}"
		done
  fi
  if [ -z "${DEFAULT_ROOTDEV}" ]; then
		dev=""
  else
		dev="/dev/$(basename ${DEFAULT_ROOTDEV})"
  	if [ ! -b "${dev}" ]; then
  		dev=""
  	fi
	fi
  echo "${dev}"
}

runscript() {
	stty echo
	tput cnorm
	echo "$1"
	employ as_system "$1"
	menu_reset
	full_menu
}

selector() {
	for option in ${!options[@]}; do
		if [[ $selected_index == $option ]]; then
			${functions[$option]}
		fi
	done
}

menu_logo() {
	echo -ne "\033]0;MOSH\007"
  echo -e "Welcome to MOSH, the Modmium developer shell\n\nIf you got here by mistake, don't panic! Just close this tab and carry on.\n\nThis shell contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
}

employ() { # this named employ to scare fanxql away
	clear
  trap 'kill -2 $! >/dev/null 2>&1' INT
  	(
    	$@
    )
  trap '' INT
  clear
}

runscriptnoroot() {
	stty echo
	tput cnorm
	echo "$1"
	employ "$1"
	menu_reset
	full_menu
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

	echo -e "$menuText" # this is so you can add extra text to menus like nix-preinstall.sh without rewriting the display_menu function in it

  for i in "${!options[@]}"; do
  	if [[ $i -eq $selected_index ]]; then
			printf "\e[7m > $(($i + 1))) ${options[$i]} \e[0m\n"
    else
    	printf "   $(($i + 1))) ${options[$i]}      \n"
  	fi
  done
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
quit(){
	stty echo
	tput cnorm
	clear
	command exit 0
}
