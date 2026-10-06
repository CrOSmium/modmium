#!/bin/bash

# written by DMD

MOSH_FRONTEND=${MOSH_FRONTEND:-terminal}
MOSH_GUI_MODE=${MOSH_GUI_MODE:-run}
MOSH_GUI_ACTION=${MOSH_GUI_ACTION:-}
MOSH_GUI_ALLOWED=${MOSH_GUI_ALLOWED:-}
MOSH_GUI_ARG_COUNT=${MOSH_GUI_ARG_COUNT:-0}
mosh_gui_arg_index=0
mosh_gui_action_ids=()
mosh_gui_action_functions=()
mosh_gui_action_min_args=()
mosh_gui_action_max_args=()
mosh_gui_action_validators=()
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
# -----------------------

if [[ $MOSH_FRONTEND == gui ]]; then
  B= G= Y= R= P= N= D= UN= RUN=
else
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
fi
MILESTONE=$(grep MILESTONE /etc/lsb-release | cut -d= -f2 | tr -d '\r')

mosh_wire_text() {
  local text=$1
  text=${text//$'\t'/ }
  text=${text//$'\r'/}
  text=${text//$'\n'/ }
  printf %s "$text"
}

mosh_wire_field() {
  local text=$1
  text=${text//'%'/'%25'}
  text=${text//$'\t'/'%09'}
  text=${text//$'\r'/'%0D'}
  text=${text//$'\n'/'%0A'}
  printf %s "$text"
}

mosh_gui_action() {
  local id=$1 function=$2 min_args=${3:-0} max_args=${4:-0} validator=${5-}
  [[ $id =~ ^[A-Za-z0-9._-]+$ && $function =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || command exit 2
  [[ $min_args =~ ^[0-9]+$ && $max_args =~ ^[0-9]+$ && $min_args -le $max_args ]] || command exit 2
  (( max_args == 0 )) || [[ -n $validator ]] || command exit 2
  mosh_gui_action_ids+=("$id")
  mosh_gui_action_functions+=("$function")
  mosh_gui_action_min_args+=("$min_args")
  mosh_gui_action_max_args+=("$max_args")
  mosh_gui_action_validators+=("$validator")
  if [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == describe ]]; then
    printf 'MOSH1\taction\t%s\t%s\t%s\n' "$id" "$min_args" "$max_args"
  fi
}

mosh_gui_state() {
  local key=$1 type=$2 value=${3-}
  [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == state ]] || return 0
  printf 'MOSH1\tstate\t%s\t%s\t' "$key" "$type"
  mosh_wire_field "$value"
  printf '\n'
}

mosh_gui_state_item() {
  local key=$1 value=${2-}
  [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == state ]] || return 0
  printf 'MOSH1\tstate-item\t%s\t' "$key"
  mosh_wire_field "$value"
  printf '\n'
}

mosh_gui_state_list() {
  local key=$1
  [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == state ]] || return 0
  printf 'MOSH1\tstate-list\t%s\n' "$key"
}

mosh_gui_metadata_done() {
  if [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == describe ]]; then
    command exit 0
  fi
}

mosh_gui_state_done() {
  if [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == state ]]; then
    command exit 0
  fi
}

mosh_gui_arg() {
  local name=MOSH_GUI_ARG_$1
  printf %s "${!name-}"
}

mosh_gui_is_choice() {
  local value=$1 choice
  shift
  for choice in "$@"; do
    [[ $value == "$choice" ]] && return 0
  done
  return 1
}

mosh_gui_is_milestone() {
  [[ $1 =~ ^[0-9]+$ ]] && (( 10#$1 >= 80 && 10#$1 <= 999 ))
}

mosh_gui_is_filename() {
  [[ -n $1 && ${#1} -le 128 && $1 != */* && $1 =~ ^[A-Za-z0-9_.+-]+$ ]]
}

mosh_gui_is_relative_path() {
  [[ -n $1 && ${#1} -le 512 && $1 != /* && $1 != *$'\n'* && $1 != *$'\r'* ]] || return 1
  [[ /$1/ != */../* ]]
}

mosh_gui_is_device_path() {
  [[ $1 == /home/user/* || $1 == /mnt/stateful_partition/* ]] || return 1
  [[ ${#1} -le 512 && $1 != *$'\n'* && $1 != *$'\r'* && /$1/ != */../* ]]
}

mosh_gui_is_name() {
  [[ -n $1 && ${#1} -le ${2:-64} && $1 =~ ^[A-Za-z0-9_.-]+$ ]]
}

mosh_gui_is_shell() {
  [[ -n $1 && ${#1} -le 128 && $1 =~ ^[A-Za-z0-9/_.+-]+$ ]]
}

mosh_gui_is_domain() {
  [[ -n $1 && ${#1} -le 253 && $1 == *.* && $1 != *. && $1 =~ ^[A-Za-z0-9.-]+$ ]]
}

mosh_gui_is_github_url() {
  local path owner repository extra
  path=${1#https://github.com/}
  [[ $path != "$1" ]] || return 1
  path=${path%.git}
  IFS=/ read -r owner repository extra <<< "$path"
  [[ -z $extra ]] || return 1
  mosh_gui_is_name "$owner" 100 && mosh_gui_is_name "$repository" 100
}

mosh_gui_is_apps_config() {
  local contents=$1 line command name entries=0
  [[ ${#contents} -le 16384 ]] || return 1
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *'|'* ]] || return 1
    command=${line%%|*}
    name=${line#*|}
    [[ -n ${command//[[:space:]]/} && -n ${name//[[:space:]]/} ]] || return 1
    entries=$((entries + 1))
  done <<< "$contents"
  (( entries <= 38 ))
}

mosh_gui_dispatch() {
  local i id function min_args max_args validator
  [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == run && -n $MOSH_GUI_ACTION ]] || return 0
  for i in "${!mosh_gui_action_ids[@]}"; do
    id=${mosh_gui_action_ids[$i]}
    [[ $id == "$MOSH_GUI_ACTION" ]] || continue
    function=${mosh_gui_action_functions[$i]}
    min_args=${mosh_gui_action_min_args[$i]}
    max_args=${mosh_gui_action_max_args[$i]}
    validator=${mosh_gui_action_validators[$i]}
    [[ $MOSH_GUI_ARG_COUNT =~ ^[0-9]+$ ]] || command exit 2
    (( MOSH_GUI_ARG_COUNT >= min_args && MOSH_GUI_ARG_COUNT <= max_args )) || command exit 2
    [[ -z $validator ]] || "$validator" || command exit 2
    mosh_gui_arg_index=0
    unset MOSH_GUI_ACTION
    printf 'MOSH1\tstarted\t%s\n' "$id"
    "$function"
    printf 'MOSH1\tdone\t%s\n' "$id"
    command exit 0
  done
  printf 'MOSH1\terror\taction unavailable\n'
  command exit 2
}

mosh_gui_entrypoint() {
  local id=$1 min_args=${2:-0} max_args=${3:-0} validator=${4-}
  [[ $id =~ ^[A-Za-z0-9._-]+$ ]] || command exit 2
  [[ $min_args =~ ^[0-9]+$ && $max_args =~ ^[0-9]+$ && $min_args -le $max_args ]] || command exit 2
  (( max_args == 0 )) || [[ -n $validator ]] || command exit 2
  if [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == describe ]]; then
    printf 'MOSH1\taction\t%s\t%s\t%s\n' "$id" "$min_args" "$max_args"
    return 0
  fi
  [[ $MOSH_FRONTEND == gui && $MOSH_GUI_MODE == run ]] || return 0
  [[ $MOSH_GUI_ACTION == "$id" && $MOSH_GUI_ARG_COUNT =~ ^[0-9]+$ ]] || command exit 2
  (( MOSH_GUI_ARG_COUNT >= min_args && MOSH_GUI_ARG_COUNT <= max_args )) || command exit 2
  [[ -z $validator ]] || "$validator" || command exit 2
  printf 'MOSH1\tstarted\t%s\n' "$id"
  unset MOSH_GUI_ACTION
}

if [[ $MOSH_FRONTEND == gui ]]; then
  read() {
    local argument variable=REPLY skip=0 input_name input
    for argument in "$@"; do
      if [[ $skip == 1 ]]; then
        skip=0
        continue
      fi
      case $argument in
        -p|-i|-n|-t|-u) skip=1 ;;
        -*p*|-*i*) skip=1 ;;
        -*) ;;
        *) variable=$argument ;;
      esac
    done
    [[ $variable =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    input_name=MOSH_GUI_ARG_${mosh_gui_arg_index}
    [[ -v $input_name ]] || return 1
    input=${!input_name}
    mosh_gui_arg_index=$((mosh_gui_arg_index + 1))
    printf -v "$variable" %s "$input"
  }
fi

mosh_input() {
  local variable=$1 prompt=$2 default=${3-} input argument
  if [[ $MOSH_FRONTEND == gui ]]; then
    argument=MOSH_GUI_ARG_${mosh_gui_arg_index:-0}
    input=${!argument-$default}
    mosh_gui_arg_index=$(( ${mosh_gui_arg_index:-0} + 1 ))
  else
    read -rep "$prompt" input
    [[ -z $input ]] && input=$default
  fi
  printf -v "$variable" %s "$input"
}

mosh_confirm() {
  local answer
  mosh_input answer "$1 [y/N] " n
  [[ $answer == y || $answer == Y || $answer == yes || $answer == true ]]
}

mosh_gui_run_action() {
  local id=$1 function=$2
  [[ $MOSH_FRONTEND == gui && $MOSH_GUI_ACTION == "$id" ]] || return 1
  [[ " $MOSH_GUI_ALLOWED " == *" $id "* ]] || command exit 2
  unset MOSH_GUI_ACTION
  printf 'MOSH1\tstarted\t%s\n' "$id"
  "$function"
  printf 'MOSH1\tdone\t%s\n' "$id"
  command exit 0
}

mosh_gui_menu() {
  local i id control view enabled title
  title=${gui_title:-$menuText}
  printf 'MOSH1\tmenu\t'
  mosh_wire_text "$title"
  printf '\n'

  for i in "${!options[@]}"; do
    id=${action_ids[$i]:-${functions[$i]}}
    control=${gui_controls[$i]:-action}
    view=${gui_views[$i]:-}
    enabled=${gui_enabled[$i]:-}
    if [[ -z $enabled ]]; then
      enabled=0
      [[ " $MOSH_GUI_ALLOWED " == *" $id "* ]] && enabled=1
    fi
    printf 'MOSH1\titem\t%s\t' "$id"
    mosh_wire_text "${options[$i]}"
    printf '\t%s\t%s\t%s\n' "$control" "$view" "$enabled"
  done

  [[ -z $MOSH_GUI_ACTION ]] && command exit 0
  for i in "${!options[@]}"; do
    id=${action_ids[$i]:-${functions[$i]}}
    enabled=${gui_enabled[$i]:-}
    if [[ -z $enabled ]]; then
      enabled=0
      [[ " $MOSH_GUI_ALLOWED " == *" $id "* ]] && enabled=1
    fi
    if [[ $id == "$MOSH_GUI_ACTION" && $enabled == 1 ]]; then
      selected_index=$i
      unset MOSH_GUI_ACTION
      printf 'MOSH1\tstarted\t%s\n' "$id"
      "${functions[$i]}"
      printf 'MOSH1\tdone\t%s\n' "$id"
      command exit 0
    fi
  done
  printf 'MOSH1\terror\taction unavailable\n'
  command exit 2
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
  if [[ $MOSH_FRONTEND == gui ]]; then
    if declare -F "$1" >/dev/null; then
      "$1"
    else
      as_system clearsecbits "$1"
    fi
    return
  fi
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
  if [[ $MOSH_FRONTEND == gui ]]; then
    if declare -F "$1" >/dev/null; then
      "$1"
    else
      "$1"
    fi
    return
  fi
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
    echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N} (Modmium ${modver} ${branch}), which is not officially supported by Modmium."
  elif [[ "$STABLEVERSIONS" =~ (^|,)"$MILESTONE"(,|$) ]]; then
    echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} (Modmium ${modver} ${branch}) --"
  else
    echo -e "-- You are currently on ChromeOS ${R}v$MILESTONE${N} (Modmium ${modver} ${branch}) -- [This ChromeOS version hasn't been tested by the Modmium devs, but it will likely still work fine.]"
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
}
full_menu() {
  [[ $MOSH_FRONTEND == gui ]] && mosh_gui_menu
  keymap="1234567890-=qwertyuiopasdfghjklzxcvbnm" # map of keys for each option, so 11 would be '-', and 13 would be 'q'
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
  selector
}
quit(){
  stty echo
  tput cnorm
  clear
  command exit 0
}
