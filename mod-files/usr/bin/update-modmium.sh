#!/bin/bash
# written by mariah carey and DMD

fail(){
  start powerd &>/dev/null
  local ec=$?
  echo -e "$1"
  sleep 2
  [[ ! $ec -eq 0 ]] && exit $ec
  exit 1
}

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

if ! which git &>/dev/null || ! which file &>/dev/null; then
	echo -e "${R}Dependencies not installed, installing...${N}"
	source /etc/profile # required to get emerge working in mosh
	if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
	  printf 'y\n\nn' | dev_install --reinstall
		touch /mnt/stateful_partition/.devinstall_complete
	fi
	ldconfig # reload shared libraries to include python libs
	emerge git file
	cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
fi

intdis=$(rootdev -d)
if echo "$intdis" | grep -q '[0-9]$'; then
  intdis_prefix="$intdis"p
else
  intdis_prefix="$intdis"
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

askBranch(){
  branchfile="$(cat /.branch)"
  [[ $branchfile ]] || branchfile="stable"
  echo -e "[If you don't know what this means, just press enter]"
  if [[ $branchfile == "stable" ]]; then
  	echo -ne "Branch of Modmium to install (${UN}stable${RUN}, nightly): "
  else
    echo -ne "Branch of Modmium to install (stable, ${UN}nightly${RUN}): "
  fi
  read -rep "" branchreq
  case $branchreq in
    nightly)
	  branch="nightly"
	  ;;
	stable)
	  branch="stable"
      ;;
	*)
	  branch="${branchfile}"
	  ;;
  esac
  echo # weird UI glitch if this isn't here, idk man
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
     cp -r /usr/share/.policy-test-tool/* /usr/local/share/policy-test-tool
	fi
}

updateModmium() {
	clear
	stty echo
	export PATH="${PATH}:/usr/local/libexec/git-core" # just in case, so we know git https will work
	askBranch
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	[[ -d modmium ]] && rm -rf modmium
	if [[ -d /root/.ssh ]]; then
	  [[ ! -d /home/chronos/user/.ssh ]] && mkdir /home/chronos/user/.ssh
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
  stop powerd &>/dev/null
  ldconfig
  stty echo
  echo -e "${D}Note: this script grabs the current kernver and signs the new version with it, so there's no issues with upgrading or downgrading.${N}"
  echo -ne "Version of ChromeOS you want to install: "
  read -rep "" VERSION
  [[ $VERSION =~ ^[0-9]+$ ]] || fail "${R}Version must be numeric, exiting...${N}"
  if [[ $VERSION -lt $MILESTONE ]]; then
  	echo -e "${R}WARNING: YOU ARE DOWNGRADING CHROMEOS ($MILESTONE -> $VERSION), THIS MAY CAUSE PROBLEMS OR WIPE USER DATA.${N}\nDo not make an issue report if you run into problems."
	echo -e "${B}Continue anyways? [y/N]${N}"
	read -rep ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${B}Continuing...\n${N}"
    else
      fail "${R}Exiting...${N}"
    fi
  fi
  if [[ $VERSION -lt 131 ]]; then
    echo -e "${R}WARNING: VERSIONS BELOW 131 ARE NOT SUPPORTED.${N}\nDo not make an issue report if you run into problems."
    echo -e "${B}Continue anyways? [y/N]${N}"
    read -rep ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${B}Continuing...${N}"
    else
      fail "${R}Exiting...${N}"
    fi
  fi
  askBranch
  getImageLink

	installKern=${intdis_prefix}$(opposite_num $(get_booted_kernnum))
	installRoot=${intdis_prefix}$(opposite_num $(get_booted_rootnum))
	echo -e "${G}Installing ChromeOS to disk...${N}"
	cd /usr/local
	python -m venv .venv
	source .venv/bin/activate
	pip install requests &>/dev/null
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
	# end aurora-inspired part
	futility vbutil_kernel --repack ${installKern} \
	  --keyblock ${keydir}/kernel.keyblock \
		--signprivate ${keydir}/kernel_data_key.vbprivk \
		--config config.txt \
		--version $kernver \
		--oldblob ${installKern} || fail "${R}Failed to remove verity, exiting...${N}"
	rm -rf config.txt

  echo -e "${G}Installing Modmium ($branch) to ChromeOS...${N}"
  export PATH="${PATH}:/usr/local/libexec/git-core" # just in case, so we know git https will work
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	[[ -d modmium ]] && rm -rf modmium
	if [[ -d /root/.ssh ]]; then
	  [[ ! -d /home/chronos/user/.ssh ]] && mkdir /home/chronos/user/.ssh
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
  [[ $arch == *"ARM"* ]] && arch=aarch64
  cp build-utils/lib/minioverride-${arch}.so mnt/lib/minioverride.so
  rm -rf mnt/root/.force_update_firmware mnt/opt/google/cr50 mnt/opt/google/ti50
  [[ -d /usr/share/vboot/userkeys ]] && cp -r /usr/share/vboot/userkeys mnt/usr/share/vboot

  # now to copy relevant files to new root
  for file in /bootsplash /.branch; do
    [[ -d $file || -f $file ]] && cp -r $file mnt
  done
  [[ -d /nix ]] && mkdir mnt/nix # we don't copy contents because the actual contents are in stateful
  echo -e "${B}Copy root's files to new root? [Y/n]${N}"
  read -rep ""
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Continuing..."
  else
    for file in $(find /root -mindepth 1 -maxdepth 1 -name "*"); do
      cp -r $file mnt/root
    done
  fi
  mkdir -p /tmp/install_marker
  mount ${intdis_prefix}12 /tmp/install_marker
  touch /tmp/install_marker/.install_complete
  umount /tmp/install_marker
  rmdir /tmp/install_marker
  echo -e "${G}Syncing filesystem (may take a while)...${N}"
  sync
  umount mnt
  cd .. && rm -rf modmium

  echo -e "${G}Done, reboot to apply update!!${N}"
  activekern=$(get_booted_kernnum)
  inactivekern=$(opposite_num "${activekern}")
  cgpt add -P 0 -T 0 -S 0 -i ${activekern} ${intdis}
  cgpt add -P 15 -T 5 -S 1 -i ${inactivekern} ${intdis}
  start powerd &>/dev/null
  sleep 2
  stty -echo
  exit 0
}




# -- NON UPDATER FUNCTIONS --

toggleBootPriority(){
  clear
  mkdir -p /tmp/install_marker
  mount ${intdis_prefix}12 /tmp/install_marker
  if [[ ! -f /tmp/install_marker/.install_complete ]]; then
    umount /tmp/install_marker
    rmdir /tmp/install_marker
    echo -e "${R}ChromeOS update has not completed yet.${N}"
    sleep 3
    exit 1
  fi
  umount /tmp/install_marker
  rmdir /tmp/install_marker
  if (( $(cgpt show -n "$intdis" -i 2 -P) > $(cgpt show -n "$intdis" -i 4 -P) )); then
    currentKern=2
    newKern=4
  else
    currentKern=4
    newKern=2
  fi
  cgpt add $intdis -i $currentKern -P 0 -S 1 -T 0
  cgpt add $intdis -i $newKern -P 15 -S 0 -T 15
  echo -e "${G}Done! Switched to kernel on ${intdis_prefix}${newKern}${N}"
  sleep 3
  exit
}

toggleEnrollment(){
	runscript /usr/bin/toggle-enrollment.sh
}
# -- MAIN SCRIPT --

tput civis # :whale:

menu_reset() {
  menuText="\nModmium Manager\n"
  options=("Update Modmium" "Change ChromeOS Version" "Toggle Enrollment" "Swap Boot Priority" "Exit")
  functions=("updateModmium" "installCros" "toggleEnrollment" "toggleBootPriority" "quit")
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
