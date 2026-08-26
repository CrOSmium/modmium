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
BOARD="$(grep '^CHROMEOS_RELEASE_DESCRIPTION=' /etc/lsb-release | awk '{print $NF}')"

# -- Shared constants (scripts that source this file should use these instead --
# -- of hardcoding the same URLs/paths again). modmium.sh can't use these since --
# -- it runs before this file (or the rest of the repo) exists on disk.        --
MODMIUM_REPO_SSH="git@github.com:crosmium/modmium.git"
MODMIUM_REPO_HTTPS="https://github.com/crosmium/modmium.git"
RECOVERY_JSON_URL="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
DEVINSTALL_MARKER="/mnt/stateful_partition/.devinstall_complete"
MODMIUM_LOG="/mnt/stateful_partition/modmium.log"

# log_action <message> — appends a timestamped line to the shared Modmium
# log (survives powerwash-adjacent debugging since it's a plain file people
# can be asked to attach to a support request). Never fails the caller.
log_action() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$(basename -- "$0")] $1" >> "$MODMIUM_LOG" 2>/dev/null
}

# -- Default error handler. Scripts with special cleanup needs (restoring a --
# -- firmware backup, restarting powerd, etc.) can still define their own   --
# -- fail() after sourcing this file, since the later definition wins.      --
fail() {
  log_action "FAILED: $1"
  echo -e "$1"
  sleep 3
  exit 1
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

get_booted_kernnum() {
  if (( $(cgpt show -n "$intdis" -i 2 -P) > $(cgpt show -n "$intdis" -i 4 -P) )); then
    echo -n 2
  else
    echo -n 4
  fi
}
get_booted_rootnum() {
  echo $(( $(get_booted_kernnum) + 1 ))
}
opposite_num() {
  case $1 in
    2) echo -n 4 ;;
    3) echo -n 5 ;;
    4) echo -n 2 ;;
    5) echo -n 3 ;;
    *) echo -n "skid" ;;
  esac
}

convertToExt4() {
  echo -e "${Y}Converting new RootFS to ext4...${N}"
  installRoot=${intdis_prefix}$(opposite_num $(get_booted_rootnum))
  tune2fs -O has_journal -J size=16 ${installRoot} || fail "${R}Conversion failed!${N}"
  e2fsck -fDy ${installRoot} || fail "${R}Conversion failed!${N}"
  tune2fs -O extents ${installRoot} || fail "${R}Conversion failed!${N}"
  e2fsck -fDy ${installRoot} || fail "${R}Conversion failed!${N}"
  resize2fs -b ${installRoot} || fail "${R}Conversion failed!${N}"
  e2fsck -fDy ${installRoot} || fail "${R}Conversion failed!${N}"
  tune2fs -O metadata_csum ${installRoot} || fail "${R}Conversion failed!${N}"
  e2fsck -fDy ${installRoot} || fail "${R}Conversion failed!${N}"
  echo -e "${G}Conversion succeeded!${N}"
  sync;sync;sync # oh how i love you sync, hopefully what is above this will make us less reliant on your help <3
}

# Looks up a matching stable-channel recovery image URL for $BOARD/$VERSION.
# Sets $recoveryUrl on success, fails (with an actionable message) otherwise.
getImageLink() {
  echo -e "${G}Checking crosbreaker/chromeos-releases-data for recovery image URL...${N}"
  recoveryUrl=$(curl -sL $RECOVERY_JSON_URL | jq -r --arg board $BOARD --arg ver $VERSION '
    .[$board].images // []
    | map(select(
    .channel == "stable-channel" and
    (.chrome_version | startswith($ver + "."))
    ))
    | sort_by(.last_modified)
    | last
    | .url // empty
    ')
  if [[ -n $recoveryUrl && $recoveryUrl =~ dl\.google\.com ]]; then
    echo -e "${G}Recovery URL found!${N}"
    sleep 1
  else
    fail "${R}No recovery image found for ChromeOS ${VERSION} on this board. Double check the version number, or try a different one at https://cros.tech/${N}"
  fi
}

# confirm_destructive "warning" — shows a warning, then a plain y/N prompt
# (default: no). Returns success only if the user typed y/Y.
confirm_destructive() {
  echo -e "${Y}$1${N}"
  echo -ne "[y/N]: "
  read -r reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    log_action "CONFIRMED: $1"
    return 0
  else
    log_action "DECLINED: $1"
    return 1
  fi
}

# confirm_irreversible "warning" — for big, hard/impossible-to-undo steps
# (flashing firmware, wiping a partition, reinstalling the OS). Requires a
# double press of 'y' in quick succession, same as modmium.sh's install
# confirmation, so it can't be triggered by someone leaning on Enter.
confirm_irreversible() {
  echo -e "${R}$1${N}"
  read -r -n 2 -s -p "Double tap y to continue, or press any other key to cancel: " confirmation
  echo ""
  if [[ "$confirmation" == "yy" ]]; then
    log_action "CONFIRMED (irreversible): $1"
    return 0
  else
    log_action "DECLINED (irreversible): $1"
    return 1
  fi
}

# run_with_feedback "message" cmd [args...] — prints a message before running
# a command so nothing happens silently, then reports whether it succeeded.
# The command's own output (and stdin, if piped in by the caller) still
# passes straight through.
run_with_feedback() {
  local msg="$1"
  shift
  echo -e "${Y}${msg}${N}"
  log_action "START: $msg"
  "$@"
  local status=$?
  if [[ $status -eq 0 ]]; then
    echo -e "${G}Done.${N}"
    log_action "OK: $msg"
  else
    echo -e "${R}That step failed (exit code ${status}).${N}"
    log_action "FAILED (exit ${status}): $msg"
  fi
  return $status
}

# ensure_deps <package> [package...] — installs the ChromeOS dev packages
# needed by MOSH scripts (git, file, protobuf-python, etc), downloading the
# base dev image only once (tracked by $DEVINSTALL_MARKER) and always
# reporting progress instead of running silently.
ensure_deps() {
  source /etc/profile # required to get emerge working in mosh
  if [[ ! -f $DEVINSTALL_MARKER ]]; then
    run_with_feedback "Setting up ChromeOS developer packages for the first time — this can take a few minutes, please be patient..." \
      bash -c "printf 'y\n\nn' | dev_install --reinstall" \
      || fail "${R}Could not install dependencies. Connect to the internet and try again.${N}"
    touch $DEVINSTALL_MARKER
  fi
  ldconfig # reload shared libraries to include python libs
  run_with_feedback "Installing: $* ..." emerge "$@" \
    || fail "${R}Could not install ($*). Connect to the internet and try again.${N}"
  if [[ -d /usr/local/usr/share/git-core/templates ]]; then
    cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
  fi
}

runscript() {
  stty echo
  tput cnorm
  echo "$1"
  log_action "RUN: $1"
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
  log_action "RUN (noroot): $1"
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
