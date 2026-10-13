#!/bin/bash

# written by DMD

STABLEVERSIONS=$(cat /usr/share/.stable_versions.txt) # just add a version to this file if you tested it and it has no issues
source /usr/share/misc/shflags

# -- Root escalation --
as_system() {
  sudo $@
}

# -- { DO NOT MODIFY } --
selected_index=0
branch=$(cat /.branch)
modver=$(cat /usr/share/.version)
shellfile=/root/.modshell
shell="bash"
[ -s "$shellfile" ] && shell=$(<"$shellfile")
center_menu=${center_menu:-0}
voffset=${voffset:-0}
resize=0
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
  employ as_system clearsecbits "$1"
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
  if [[ "$TERM" != "xterm" ]]; then
    echo -e "Welcome to MOSH, the Modmium developer shell\n\nIf you got here by mistake, don't panic! Just close this tab and carry on.\n\nThis shell contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
  else
    echo -e "Welcome to VT-MOSH, the Modmium developer console.\n\nIf you got here by mistake, don't panic! Just press exit, then Ctrl+Alt+F1 [usually the back arrow] and carry on.\n\nThis console contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
  fi
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

centermenu() {
  local content="$1" voffset="${2:-0}"
  local rows cols line stripped w start_row start_col row
  local -a lines
  rows=$(tput lines)
  cols=$(tput cols)
  mapfile -t lines <<< "$content"
  start_row=$(( (rows - ${#lines[@]}) / 2 - voffset ))
  (( start_row < 0 )) && start_row=0
  row=$start_row
  for line in "${lines[@]}"; do
    stripped=$(printf '%s' "$line" | sed 's/\x1b\[[^a-zA-Z]*[a-zA-Z]//g; s/\x1b][^\x07]*\x07//g') # colors aren't words bash!
    w=${#stripped}
    start_col=$(( (cols - w) / 2 ))
    (( start_col < 0 )) && start_col=0
    tput cup "$row" "$start_col"
    printf '%s' "$line"
    tput el
    (( row++ ))
  done
}

display_menu() {
  local voffset="${1:-0}"
  local out
  out=$(
    menu_logo
    if [[ $displaymilestone != 0 ]]; then
      if [[ "$MILESTONE" == "" ]]; then
        echo -e "${R}Uhh... how are you seeing this if ChromeOS isn't installed..?${N}"
      elif [[ "$MILESTONE" -le 131 ]]; then
        echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N} (Modmium ${modver} ${branch}), which is not officially supported by Modmium."
      elif [[ "$STABLEVERSIONS" =~ (^|,)"$MILESTONE"(,|$) ]]; then
        echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} (Modmium ${modver} ${branch}) --"
      else
        echo -e "-- You are currently on ChromeOS ${R}v$MILESTONE${N} (Modmium ${modver} ${branch}) -- [This ChromeOS version hasn't been tested by the Modmium devs, but it will likely still work fine.]"
      fi
    fi
    echo -e "$menuText" # this is so you can add extra text to menus like nix-preinstall.sh without rewriting the display_menu function in it

    for i in "${!options[@]}"; do
      local keysel="${keymap:$i:1}"
      if [[ $i -eq $selected_index ]]; then
        printf "\e[7m > %s) ${options[$i]} \e[0m\n" "$keysel"
      else
        printf "   %s) ${options[$i]}      \n" "$keysel"
      fi
    done
  )

  if [[ "$center_menu" == "1" ]]; then
    tput cup 0 0
    tput sc
    centermenu "$out" "$voffset"
  else
    tput sc
    printf '%s\n' "$out"
  fi
}

full_menu() {
  keymap="1234567890-=qwertyuiopasdfghjklzxcvbnm" # map of keys for each option, so 11 would be '-', and 13 would be 'q'
  clear
  stty -echo
  tput civis
  [[ "$center_menu" == "1" ]] && trap 'resize=1' WINCH
  while true; do
    display_menu "${voffset:-0}"
    if [[ "$center_menu" == "1" ]]; then
      while ! read -rsn1 key 2>/dev/null; do
        if [[ $resize -eq 1 ]]; then 
          resize=0
          clear
          continue 2;
        fi
      done
    else
      read -rsn1 key
    fi
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
    elif [[ -n "$key" && "$keymap" == *"$key"* ]]; then
      prefix="${keymap%%"$key"*}"
      target_index=${#prefix}
      if [ "$target_index" -lt "$num_options" ]; then
        selected_index=$target_index
      fi
    elif [[ "$key" == "" ]]; then
      break
    fi
    tput rc
  done
  [[ "$center_menu" == "1" ]] && trap - WINCH
  selector
}
quit(){
  stty echo
  tput cnorm
  clear
  command exit 0
}
