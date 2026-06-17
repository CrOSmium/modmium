#!/bin/bash
# written by DMD, Mariah, and codenerd87

# factory ChromeOS revert is pretty much just update-modmium.sh but without the modmium part.

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:

fail(){
  echo -e "$1"
  start powerd &>/dev/null
  if [[ -f oldbios.bin && $2 == restore ]]; then
    echo -e "${B}Attempting restore from firmware backup in 3 seconds...${N}"
    sleep 3
    flashrom -w oldbios.bin
    echo -e "Done. Hopefully all is well now. Sleeping forever so you can look at logs."
    echo -e "${D}If everything looks good, hit Ctrl+C to exit.${N}"
    sleep infinity
  fi
  sleep 2
  factoryreset=0
  exit 0
}

if ! which git &>/dev/null || ! which file &>/dev/null; then
  echo -e "${R}Dependencies not installed, installing...${N}"
  source /etc/profile # required to get emerge working in mosh
  if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    touch /mnt/stateful_partition/.devinstall_complete
  fi
  ldconfig # reload shared libraries to include python libs
  emerge git file protobuf-python
  cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
fi

checkWP(){
  writeprotect=$(flashrom --wp-status 2>&1 | grep "disabled")
  if [[ $writeprotect == *"disabled"* ]]; then
    echo -e "FWWP is currently ${R}DISABLED${N}, continuing..."
  else
    echo -e "FWWP is currently ${G}ENABLED${N}, checking for wp range..."
    wprange=$(flashrom --wp-status 2>&1 | grep -E "range: start=0x[0-9a-f]+, len=0x00000000")
    if [[ $wprange != "" ]]; then
      fail "WP range is set to 0,0 but you must fully disable FWWP before continuing."
    else
      fail "WP range is still set, please disable your FWWP by following this guide: ${G}https://crosmium.dev/FWWP${N}"
    fi
  fi
}

unkeyroll(){
  futility gbb -s --flash --recoverykey="/root/.recoverykeys/$board.vbpubk"
  echo -e "Would you like to be unkeyrolled permanently? [y/N]"
  echo -e "${R}This will prevent you from reflashing devkeys until you re-disable FWWP fully${N}"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    flashrom --wp-range 0,0 || flashrom --wp-range 0 0
    flashrom --wp-enable
  fi
}

revertMPkeys(){
  clear
  stty echo
  checkWP
  echo -e "${R}This will update your firmware and revert your chromebook to stock keys (undoing developer firmware changes), are you ${UN}sure${RUN} you want to continue?${N} [y/N]"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "Restoring MPkeys, ${G}please connect your device to power (if you haven't already)${N}"
    sleep 2
    echo "Modmium stock firmware restore script by codenerd87"
    workdir=$(mktemp -d) || fail "Failed to make tmp dir"
    cd ${workdir}
    model=$(cat /tmp/machine-info | grep customization_id | sed 's/customization_id=//; s/"//g' | tr '[:upper:]' '[:lower:]') # Extends support to include super old chromeos versions where the --model argument is required
    chromeos-firmwareupdate -m output --output_dir ${workdir} --model ${model} || fail "Failed to extract firmware shellball"
    rm ec.bin image.bin #we must save 16mb ram :whale:
    echo "Reading old bios"
    flashrom -r oldbios.bin || fail "Failed to read current bios."

    echo "Extracting VPD from current bios"
    cbfstool oldbios.bin read -r RO_VPD -f rovpd.bin || fail "Failed to extract RO_VPD"
    cbfstool oldbios.bin read -r RW_VPD -f rwvpd.bin || fail "Failed to extract RW_VPD"
    echo "Injecting VPD into new bios"
    cbfstool bios.bin write -r RO_VPD -f rovpd.bin || fail "Failed to inject RO_VPD"
    cbfstool bios.bin write -r RW_VPD -f rwvpd.bin || fail "Failed to inject RW_VPD"

    echo "VPD successfully transplated"

    echo "Transplanting HWID"
    futility gbb oldbios.bin -g --hwid | sed "s/hardware_id: //" > hwid.txt || fail "Failed to extract HWID"
    futility gbb bios.bin -s --hwid="$(cat hwid.txt)" || fail "Failed to inject HWID"

    echo "HWID successfully transplated"

    echo "Setting GBB flags to 0xa0b1"
    futility gbb bios.bin -s --flags=0xa0b1 || fail "Failed to set GBB flags"

    echo "Flashing new bios, ${R}do not power off your device!${N}"
    flashrom -w bios.bin || fail "Uh oh, flash failed. Join https://discord.crosbreaker.com for support" restore
    vpd -d dev_firmware
    echo "Firmware flashed successfully!"

    if [[ $board =~ ^corsola|^dedede|^nissa ]]; then
      echo -e "${B}Do you want to unkeyroll? [y/N]"
      read -re
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        unkeyroll
      fi
    fi
    echo -e "Your device is now on MPkeys! Modmium will not boot after your device reboots, please make sure you restore factory ChromeOS or use a recovery image!"
    sleep 3
    clear
    [[ $factoryreset == 1 ]] && employ installCros
    fail "Exiting..."
  fi
  fail "Exiting..."
}

BOARD="$(grep '^CHROMEOS_RELEASE_DESCRIPTION=' /etc/lsb-release | awk '{print $NF}')"
getImageLink(){
  jsonLink="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
  echo -e "${G}Checking crosbreaker/chromeos-releases-data for recovery image URL...${N}"
  recoveryUrl=$(curl -sL $jsonLink | jq -r --arg board $BOARD --arg ver $VERSION '
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
    fail "${R}Recovery URL not found or invalid :(${N}"
  fi
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

installCros() {
  stop powerd &>/dev/null # to prevent it from falling asleep while streaming to disk
  ldconfig
  stty echo
  echo -e "Getting kernver..."
  stop trunksd &>/dev/null || stop tcsd &>/dev/null
  rawkv=$(tpmc read 0x1008 9)
  start trunksd &>/dev/null || start tcsd &>/dev/null
  # this part inspired by aurora (though obviously not copy pasted), thanks soap :3
  bytes=()
  for byte in $rawkv; do
    while [[ -n $byte ]]; do
      bytes+=( "${byte:0:2}" )
      byte="${byte:2}"
    done
  done
  if [[ ${bytes[0]} -eq 10 ]]; then
    kernver=$(( ${bytes[4]}<<0 | ${bytes[5]}<<8 ))
  elif [[ ${bytes[0]} -eq 2 ]]; then
    kernver=$(( ${bytes[5]}<<0 | ${bytes[6]}<<8 ))
  fi
  echo -e "${R}[THE VERSION YOU ARE INSTALLING MUST BE ${B}KERNVER $kernver${R} OR HIGHER]${N}\n(if not, you can just boot SH1mmer and run ${UN}chromeos-tpm-recovery${RUN})\n"
  echo -ne "Version of ChromeOS you want to install: "
  read -rep "" VERSION
  [[ $VERSION =~ ^[0-9]+$ ]] || fail "${R}Version must be numeric, exiting...${N}"
  getImageLink
  intdis=$(rootdev -d)
  if echo "$intdis" | grep -q '[0-9]$'; then
    intdis_prefix="$intdis"p
  else
    intdis_prefix="$intdis"
  fi
  installKern=${intdis_prefix}$(opposite_num $(get_booted_kernnum))
  installRoot=${intdis_prefix}$(opposite_num $(get_booted_rootnum))
  echo -e "${G}Installing ChromeOS to disk...${N}"
  cd /usr/local
  python -m venv .venv
  source .venv/bin/activate
  pip install requests &>/dev/null
  /usr/bin/stream.py --recovery-url "${recoveryUrl}" --kern-output "${installKern}" --root-output "${installRoot}" || fail "${R}Failed to install ChromeOS, refusing to change boot order, exiting...${N}"
  rm -rf .venv
   echo -e "${G}Syncing filesystem (may take a while)...${N}"
  sync
  echo -e "${G}Done, reboot to return to factory ChromeOS!${N}"
  activekern=$(get_booted_kernnum)
  inactivekern=$(opposite_num "${activekern}")
  cgpt add -P 1 -T 0 -S 1 -i ${activekern} ${intdis}
  cgpt add -P 15 -T 6 -S 0 -i ${inactivekern} ${intdis}
  sleep 1
  stty -echo
  [[ $factoryreset == 1 ]] || fail "Exiting..."
  start powerd &>/dev/null
  exit 0
}

factoryReset(){
  factoryreset=1
  revertMPkeys
}

restoreMPkeys(){
  factoryreset=0
  revertMPkeys
}

restoreOS(){
  factoryreset=0
  installCros
}

menu_reset() {
  options=("Full Factory Revert [Restore OS & MPkeys]" "Restore OS" "Revert MPkeys" "Go Back")
  functions=("factoryReset" "restoreOS" "restoreMPkeys" "quit")
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
