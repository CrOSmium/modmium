#!/bin/bash
# written by DMD and Mariah

# factory ChromeOS revert is pretty much just update-modmium.sh but without the modmium part.

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:

if ! which git &>/dev/null || ! which file &>/dev/null || ! which diff &>/dev/null; then
	echo -e "${R}Dependencies not installed, installing...${N}"
	source /etc/profile # required to get emerge working in mosh
	if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
		nohup dev_install --reinstall --yes >/root/.devinstall-log 2>&1 &
		echo -e "${G}Waiting for python dependencies from dev_install...${N}"
		pythonGoogleInstalled=
		while [[ $pythonGoogleInstalled != "true" ]]; do
  		python -m google >/root/.googleStatus 2>&1
  		output=$(cat /root/.googleStatus) # reason we have to do this is because python forces itself into stdout even if the output is supposed to be a variable i hate python
  		if [[ $output == *"package"* ]]; then
    		pythonGoogleInstalled=true
  		fi
  		sleep 1
		done
		# cleaning up
		rm -rf /root/.googleStatus /root/.devinstall_log
		touch /mnt/stateful_partition/.devinstall_complete
	fi
	ldconfig # reload shared libraries to include python libs
	emerge git diffutils file
	cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
fi

fail(){
	echo -e "$1"
	sleep 2
	factoryreset=0
	exit 0
}

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
  checkWP
  echo -e "${R}This will update your firmware and revert your chromebook to stock keys (undoing developer firmware changes), are you ${UN}sure${RUN} you want to continue?${N} [y/N]"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "Restoring MPkeys, ${G}please connect your device to power (if you haven't already)${N}"
    sleep 2
    echo -e "Preparing for restore..."
    flashrom -r /pre-restorefw.rom > /dev/null 2>&1 # backup the fw in case something fails
    echo -e "Restoring firmware, ${R}DO NOT turn off your device${N}!"
    echo -e "This may take a while..."
    # before you think about removing the weird backup, i put it there because the longer it takes the more time someone will have to realize they missed something (like their battery being low, or not plugged in)
    chromeos-firmwareupdate -m output &> /dev/null && rm -rf image.bin ec.bin
    futility gbb -gr reco.key bios.bin && futility gbb -gk root.key bios.bin
    futility gbb -sr reco.key --flash && futility gbb -sk root.key --flash
    echo -e "${G}Done!"
    if [[ $board =~ ^corsola|^dedede|^nissa ]]; then
      echo -e "${B}Do you want to unkeyroll?"
      read -re
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        unkeyroll
      fi
    fi
	fail "Exiting..."
  fi
    echo -e "Your device is now on MPkeys! Modmium will not boot after your device reboots, please make sure you restore factory ChromeOS or use a recovery image!"
    sleep 3
	clear
    [[ $factoryreset == 1 ]] && employ installCros
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
  echo -e "${R}[THE VERSION YOU ARE INSTALLING MUST BE ${B}KERNVER $kernver${R} OR HIGHER]${N}\n(if not, you can just boot SH1mmer and ${UN}chromeos-tpm-recovery${RUN})\n"
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
	cgpt add -P 0 -T 0 -S 0 -i ${activekern} ${intdis}
	cgpt add -P 15 -T 5 -S 1 -i ${inactivekern} ${intdis}
	sleep 1
	stty -echo
	[[ $factoryreset == 1 ]] || fail "Exiting..."
	exit 0
}

factoryReset(){
    factoryreset=1
	runscriptnoroot restoreMPkeys
}

restoreMPkeys(){
    factoryreset=0
	runscriptnoroot revertMPkeys
}

restoreOS(){
	factoryreset=0
	runscriptnoroot installCros
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
