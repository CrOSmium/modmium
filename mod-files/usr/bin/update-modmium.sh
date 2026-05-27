#!/bin/bash
# written by mariah carey and DMD

fail(){
  local ec=$?
  echo -e "$1"
  sleep 2
  [[ ! $ec -eq 0 ]] && exit $ec
  exit 1
}

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

if ! which git >/dev/null 2>&1; then
	echo -e "${R}git not installed, installing...${N}"
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
	emerge git diffutils
	cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
fi

# -- FUNCTIONS --
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

dropModFiles() {
	modFiles=$(find /mnt/stateful_partition/git/modmium/mod-files -mindepth 1 -name "*")
	for file in $modFiles; do
		if [[ -d $file ]]; then
			:
		elif [[ -f $file ]]; then
			realFile=$(echo "$file" | sed 's/^.*mod-files//')
			mkdir -p $(dirname $realFile)
			cp $file $realFile
			chown 0:0 $realFile
			chmod 777 $realFile
		fi
	done
	if [[ -d /usr/local/share/policy-test-tool ]]; then
		cp /root/.policy-test-tool/* /usr/local/share/policy-test-tool
	fi
}

updateModmium() {
	clear
	stty echo
	export PATH="${PATH}:/usr/local/libexec/git-core" # just in case, so we know git https will work
	branch=$(cat /.branch)
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	if [[ -d /root/.ssh ]]; then
		git clone --depth 1 -b $branch --single-branch git@github.com:crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}"
	else
		git clone --depth 1 -b $branch --single-branch https://github.com/crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}"
	fi
	echo -e "${G}Successfully cloned repository!${N} Dropping new files..."
	dropModFiles || fail "${R}Failed to drop updated files, please make an issue report on https://github.com/crosmium/modmium with details of changes you made, if any...${N}"
	echo -e "${G}Done! Cleaning up...${N}"
	rm -rf /mnt/stateful_partition/git/modmium
	sync # this is for all the times i changed stuff locally and didn't sync and suddenly it didn't boot - dmd
	sleep 3
	stty -echo
	exit
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
  stty echo
  echo -ne "Version of ChromeOS you want to install: "
  read -rep "" VERSION
  [[ $VERSION -gt 130 ]] || fail "${R}Versions below 131 are not supported, exiting...${N}"
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
	pip install requests
	/usr/bin/stream.py --recovery-url "${recoveryUrl}" --kern-output "${installKern}" --root-output "${installRoot}" || fail "${R}Failed to install ChromeOS, refusing to change boot order, exiting...${N}"
	rm -rf .venv
	# thanks lxrd for that python script btw

	echo -e "${G}Removing verity from ChromeOS...${N}"
	if [[ -d /usr/share/vboot/userkeys ]]; then
	  keydir=/usr/share/vboot/userkeys
	else
	  keydir=/usr/share/vboot/devkeys
	fi
	/usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --partitions $(opposite_num $(get_booted_kernnum)) --keys ${keydir} &>/dev/null
	futility dump_kernel_config ${installKern} > config.txt
	sed -i "s|cros_secure|cros_secure cros_debug|g" config.txt
	sed -i 's/  */ /g; s/^ //; s/ $//' config.txt # fix double spacing
	stop trunksd &>/dev/null
	rawkv=$(tpmc read 0x1008 9)
	start trunksd &>/dev/null
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
	# end aurora-inspired part
	futility vbutil_kernel --repack ${installKern} \
	  --keyblock ${keydir}/kernel.keyblock \
		--signprivate ${keydir}/kernel_data_key.vbprivk \
		--config config.txt \
		--version $kernver \
		--oldblob ${installKern} || fail "${R}Failed to remove verity, exiting...${N}"
	rm -rf config.txt

  echo -e "${G}Installing Modmium to ChromeOS...${N}"
  export PATH="${PATH}:/usr/local/libexec/git-core" # just in case, so we know git https will work
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	if [[ -d /root/.ssh ]]; then
		git clone --depth 1 -b $branch --single-branch git@github.com:crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}"
	else
		git clone --depth 1 -b $branch --single-branch https://github.com/crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}"
	fi
	echo -e "${G}Successfully cloned repository!${N} Dropping new files..."

	cd modmium
	mount ${installRoot} mnt --mkdir
	for file in $(find mod-files -mindepth 1 -name "*"); do
    if [[ -d $file ]]; then
      :
    elif [[ -f $file ]]; then
      oldFile=$(echo $file | sed 's/mod-files/mnt/')
      dir=$(dirname $oldFile)
      if [[ -f $oldFile ]]; then
        mv $oldFile "$oldFile".old
      fi
      mkdir -p $dir
      cp $file $oldFile
      chown 0:0 $oldFile
      chmod 777 $oldFile
    fi
  done
  arch=$(file mnt/bin/bash | awk -F', ' '{print $2}')
  cp build-utils/lib/minioverride-${arch}.so mnt/lib/minioverride.so
  rm -rf mnt/root/.force_update_firmware mnt/opt/google/cr50 mnt/opt/google/ti50

  # now to copy relevant files to new root
  for file in /bootsplash /.branch; do
    [[ -d $file || -f $file ]] && cp -r $file mnt
  done
  [[ -d /nix ]] && mkdir mnt/nix # we don't copy contents because the actual contents are in stateful
  if ! diff /root/.bashrc mnt/root/.bashrc; then
    echo -e "${B}Changes to .bashrc detected, copy root's dotfiles to new root? [Y/n]${N}"
    read -rep ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      echo "Continuing..."
    else
      for file in $(find /root -name ".*" ! -name ".policy-test-tool" ! -name ".stable_versions.txt" ! -name ".unhang.sh"); do
        cp -r $file mnt/root
      done
    fi
  fi
  echo -e "${G}Syncing filesystem (may take a while)...${N}"
  sync
  umount mnt
  cd .. && rm -rf modmium

  echo -e "${G}Done, have fun!${N}"
	cgpt add -P 0 -T 1 -S 0 -i $(get_booted_kernnum) ${intdis}
	cgpt add -P 15 -T 5 -S 0 -i $(opposite_num $(get_booted_kernnum)) ${intdis}
	sleep 2
	stty -echo
	exit 0
}

# -- MAIN SCRIPT --

tput civis # :whale:

menu_reset() {
  menuText="\nModmium Update Utility\n"
  options=("Update Modmium" "Change ChromeOS Version" "Exit")
  functions=("updateModmium" "installCros" "quit")
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
