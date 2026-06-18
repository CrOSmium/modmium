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

stty -echo
source /usr/lib/libmosh.sh

if ! which git &>/dev/null || ! which file &>/dev/null; then
  echo -e "${R}Dependencies not installed, installing...${N}"
  source /etc/profile
  if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    touch /mnt/stateful_partition/.devinstall_complete
  fi
  ldconfig
  emerge git file
  cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core
fi

intdis=$(rootdev -d)
if echo "$intdis" | grep -q '[0-9]$'; then
  intdis_prefix="$intdis"p
else
  intdis_prefix="$intdis"
fi

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
  if [[ -z $recoveryUrl || ! $recoveryUrl =~ dl\.google\.com ]]; then
    fail "${R}Recovery URL not found or invalid :(${N}"
  fi
}

askBranch(){
  branchfile="$(cat /.branch)"
  [[ $branchfile ]] || branchfile="stable"
  read -rep "Branch of Modmium (stable, nightly): " branchreq
  case $branchreq in
    nightly) branch="nightly" ;;
    stable) branch="stable" ;;
    *) branch="${branchfile}" ;;
  esac
}

dropModFiles() {
  modFiles=$(find /mnt/stateful_partition/git/modmium/mod-files -mindepth 1 -name "*")
  for file in $modFiles; do
    if [[ -f $file ]]; then
      realFile=$(echo "$file" | sed 's/^.*mod-files//')
      mkdir -p $(dirname $realFile)
      cp $file $realFile
      chown 0:0 $realFile
      chmod 777 $realFile
    fi
  done
}

updateModmium() {
  clear
  stty echo
  askBranch
  mkdir -p /mnt/stateful_partition/git
  cd /mnt/stateful_partition/git
  rm -rf modmium

  git clone --depth 1 -b $branch --single-branch https://github.com/crosmium/modmium.git \
    || fail "${R}Failed to clone repository${N}"

  dropModFiles
  rm -rf /mnt/stateful_partition/git/modmium
  sync
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
  esac
}

installCros() {
  stop powerd &>/dev/null
  ldconfig
  stty echo

  read -rep "Version of ChromeOS: " VERSION

  askBranch
  getImageLink

  installKern=${intdis_prefix}$(opposite_num $(get_booted_kernnum))
  installRoot=${intdis_prefix}$(opposite_num $(get_booted_rootnum))

  cd /usr/local
  python -m venv .venv
  source .venv/bin/activate
  pip install requests &>/dev/null

  /usr/bin/stream.py --recovery-url "${recoveryUrl}" \
    --kern-output "${installKern}" \
    --root-output "${installRoot}" || fail "install failed"

  rm -rf .venv

  keydir=/usr/share/vboot/devkeys
  /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification \
    --partitions $(opposite_num $(get_booted_kernnum)) \
    --keys ${keydir} &>/dev/null

  mount ${installRoot} mnt --mkdir

  if [[ -f /etc/chrome_dev.conf ]]; then
    mkdir -p mnt/etc
    cp -a /etc/chrome_dev.conf mnt/etc/chrome_dev.conf
  fi

  echo "Copy root files? [y/N]"
  read REPLY
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    for file in /root/*; do
      cp -r "$file" mnt/root
    done
  fi

  umount mnt
}

toggleBootPriority(){
  clear

  if (( $(cgpt show -n "$intdis" -i 2 -P) > $(cgpt show -n "$intdis" -i 4 -P) )); then
    currentKern=2
    newKern=4
  else
    currentKern=4
    newKern=2
  fi

  if [[ -f /etc/chrome_dev.conf ]]; then
    mkdir -p /tmp/opposite
    mount ${intdis_prefix}${newKern} /tmp/opposite 2>/dev/null
    if [[ -d /tmp/opposite/etc ]]; then
      cp -a /etc/chrome_dev.conf /tmp/opposite/etc/chrome_dev.conf
    fi
    umount /tmp/opposite 2>/dev/null
    rmdir /tmp/opposite 2>/dev/null
  fi

  cgpt add $intdis -i $currentKern -P 1 -S 1 -T 0
  cgpt add $intdis -i $newKern -P 15 -S 0 -T 15
}

menu_reset() {
  menuText="\nModmium Manager\n"
  options=("Update Modmium" "Change ChromeOS Version" "Swap Boot Priority" "Toggle Enrollment" "Add Local Account" "Exit")
  functions=("updateModmium" "installCros" "toggleBootPriority" "toggleEnrollment" "localAcc" "quit")
}

menu_reset
clear
full_menu
tput cnorm
selector
