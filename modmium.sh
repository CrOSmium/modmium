#!/bin/bash
# written by DMD and mariah carey
# compatibility fixes by codenerd87
source /usr/share/misc/shflags

# The flag below sets the backup flag to false* by default when set to '1', and just continues after disabling rootFS verification instead of prompting for a reboot.
# *Backing up isn't *as* important as it used to be, since we can revert devkeys inside modmium, but it's staying true by default for the main installer.

# You can set this flag to '$FLAGS_TRUE' if you want modmium to install with the bare minimum amount of user prompts
QUICKINSTALL=$FLAGS_FALSE

default_backup=$FLAGS_TRUE
[[ $QUICKINSTALL == $FLAGS_TRUE ]] && default_backup=$FLAGS_FALSE
DEFINE_boolean userkeys "$FLAGS_FALSE" "Whether or not to use user-generated signing keys." "u"
DEFINE_boolean backup "$default_backup" "Whether or not to backup firmware from flashing devkeys." "b"
FLAGS $@
[[ $QUICKINSTALL == $FLAGS_TRUE ]] && export FLAG_userkeys=$FLAGS_FALSE

fail(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [modmium.sh] FAILED: $1" >> "$MODMIUM_LOG" 2>/dev/null
  echo -e "$1"
  if [[ $2 != "keepflag" ]]; then
    vpd -d dev_firmware
  fi
  umount $BACKUP >/dev/null 2>&1
  sleep 3
  exit 1
}

# -- FLAGS --
menu_text="Modmium Install Script!"
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
[[ $QUICKINSTALL == $FLAGS_TRUE ]] && menu_text="Modmium Install Script! (Quickinstall)"

# -- Constants --
# These are hardcoded (instead of sourced from a shared lib like libmosh.sh)
# because this script runs before Modmium's repo exists on disk at all -
# it's the thing that clones the repo in the first place.
MODMIUM_REPO_SSH="git@github.com:crosmium/modmium.git"
MODMIUM_REPO_HTTPS="https://github.com/crosmium/modmium.git"
RECOVERY_JSON_URL="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
DEVINSTALL_MARKER="/mnt/stateful_partition/.devinstall_complete"
STREAM_PY_URL="https://modmium.dev/tools/stream.py"
MODMIUM_LOG="/mnt/stateful_partition/modmium.log" # same path libmosh.sh logs to post-install

log_action() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [modmium.sh] $1" >> "$MODMIUM_LOG" 2>/dev/null
}

# confirm_destructive "warning": plain y/N prompt, default no.
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

# confirm_irreversible "warning": double tap y so leaning on Enter can't trigger it.
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

# run_with_feedback "message" cmd [args...]: no more silent long-running steps.
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

# ensure_deps <package> [package...]: installs the ChromeOS dev packages
# needed to clone/build Modmium, only bootstrapping dev_install once.
ensure_deps() {
  source /etc/profile # required to get emerge working
  if [[ ! -f $DEVINSTALL_MARKER ]]; then
    run_with_feedback "Setting up ChromeOS developer packages for the first time, this can take a few minutes, please be patient..." \
      bash -c "printf 'y\n\nn' | dev_install --reinstall" \
      || fail "${R}Could not install dependencies. Connect to the internet and try again.${N}" keepflag
    touch $DEVINSTALL_MARKER
  fi
  ldconfig # reload shared libraries to include python libs
  run_with_feedback "Installing: $* ..." emerge "$@" \
    || fail "${R}Could not install ($*). Connect to the internet and try again.${N}" keepflag
  if [[ -d /usr/local/usr/share/git-core/templates ]]; then
    cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
  fi
}

# -- skidded from modmium-update.sh --
BOARD="$(grep '^CHROMEOS_RELEASE_DESCRIPTION=' /etc/lsb-release | awk '{print $NF}')"
getImageLink(){
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
    fail "${R}No recovery image found for ChromeOS ${VERSION} on this board. Double check the version number, or ask in the Discord (${Y}discord.crosbreaker.com${R}).${N}"
  fi
}

askBranch(){
  branchfile="stable"
  echo -e "[If you don't know what this means, just press enter]"
  echo -ne "Branch of Modmium to install (${G}stable${N}, nightly): "
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

convertToExt4(){
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

installCros() {
  stop powerd &>/dev/null
  ldconfig
  clear
  echo -e "${D}Note: this script grabs the current kernver and signs the new version with it, so there's no issues with upgrading or downgrading.${N}"
  echo -ne "Version of ChromeOS you want to install: "
  read -rep "" VERSION
  [[ $VERSION =~ ^[0-9]+$ ]] || fail "${R}Version must be numeric, exiting...${N}" keepflag
  if [[ $VERSION -lt 131 ]]; then
    confirm_destructive "WARNING. VERSIONS BELOW 131 ARE NOT SUPPORTED.\nDo not make an issue report if you run into problems.\nContinue anyways?" \
      || fail "${R}Exiting...${N}" keepflag
  fi
  if [[ $QUICKINSTALL == $FLAGS_FALSE ]]; then
    confirm_irreversible "This will install ChromeOS $VERSION onto the inactive partition. This cannot be undone once it starts." \
      || fail "${R}Exiting...${N}" keepflag
  fi
  askBranch
  getImageLink
  intdis=$(rootdev -s -d)
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
  streamdir=/root/ # might as well if rootfs verification is already off ig, im keeping this as default just because i don't want to break anything - dmd
  [[ $QUICKINSTALL == $FLAGS_TRUE ]] && streamdir=/usr/local/
  curl -fLo ${streamdir}stream.py "$STREAM_PY_URL" || fail "${R}Failed to download the ChromeOS streaming tool. Connect to the internet and try again.${N}" keepflag
  run_with_feedback "Streaming ChromeOS $VERSION to disk, this can take several minutes..." \
    python ${streamdir}stream.py --recovery-url "${recoveryUrl}" --kern-output "${installKern}" --root-output "${installRoot}" \
    || fail "${R}Failed to install ChromeOS, refusing to change boot order, exiting...${N}" keepflag
  rm -rf .venv
  # thanks lxrd for that python script btw
  echo -e "${G}Removing verity from ChromeOS...${N}"
  # keydir gets defined in modmiumInstall()
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
    --oldblob ${installKern} || fail "${R}Failed to remove verity, exiting...${N}" keepflag
  rm -rf config.txt
  convertToExt4
  echo -e "${G}Installing Modmium ($branch) to ChromeOS...${N}"
  export PATH="${PATH}:/usr/local/libexec/git-core" # just in case, so we know git https will work
  mkdir -p /mnt/stateful_partition/git
  cd /mnt/stateful_partition/git
  if [[ -d /root/.ssh ]]; then
    [[ ! -d /home/chronos/user/.ssh ]] && mkdir /home/chronos/user/.ssh
    git clone --depth 1 -b $branch --single-branch $MODMIUM_REPO_SSH || fail "${R}Failed to clone repository, exiting...${N}" keepflag
  else
    git clone --depth 1 -b $branch --single-branch $MODMIUM_REPO_HTTPS || fail "${R}Failed to clone repository, exiting...${N}" keepflag
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
  [[ -d ${BACKUP}/userkeys ]] && cp -r ${BACKUP}/userkeys mnt/usr/share/vboot
  echo $branch > mnt/.branch

  echo -e "${G}Syncing filesystem (may take a while)...${N}"
  sync;sync;sync;sync # do not touch this.
  umount mnt
  cd .. && rm -rf modmium
  sync
  if [[ $QUICKINSTALL == $FLAGS_FALSE ]]; then
    if confirm_destructive "Would you like to powerwash? (Can prevent blackscreening on boot)"; then
      echo -e "Your device ${R}will${N} powerwash on next boot."
      echo "fast safe keepimg" > /mnt/stateful_partition/factory_install_reset
      sleep 0.3
    else
      echo -e "Your device will ${R}NOT${N} powerwash on next boot."
      sleep 0.3
    fi
    # this is for compatability with other chromeos versions
    echo -e "${Y}Remove developer packages for compatibility with other ChromeOS versions? [Y/n]${N}"
    read -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      run_with_feedback "Uninstalling packages..." bash -c "printf 'y\n' | dev_install --uninstall"
      rm -f $DEVINSTALL_MARKER
    else
      echo -e "${B}Keeping packages installed.${N}"
    fi
  else
    run_with_feedback "Uninstalling packages..." bash -c "printf 'y\n' | dev_install --uninstall"
    rm -f $DEVINSTALL_MARKER
  fi

  echo -e "Switching active kernel..."
  activekern=$(get_booted_kernnum)
  inactivekern=$(opposite_num "${activekern}")
  cgpt add -P 1 -T 0 -S 1 -i ${activekern} ${intdis}
  cgpt add -P 15 -T 6 -S 0 -i ${inactivekern} ${intdis}
  sync;sync;sync  # i do not trust chromeOS.
  echo -e "${G}Done! Would you like to reboot now? [Y/n]${N}"
  read -n1 -r
  if [[ $REPLY =~ ^[Nn]$ ]]; then 
    echo -e "${B}Reboot when ready! Exiting...${N}"
    sleep 2
    start powerd &>/dev/null
    exit 0
  else
    echo -e "${B}Rebooting!${N}"
    reboot
    sleep infinity
  fi
}


# -- MAIN SCRIPT --
logo() {
    echo -e "
 ██████   ██████              █████                  ███
▒▒██████ ██████              ▒▒███                  ▒▒▒
 ▒███▒█████▒███   ██████   ███████  █████████████   ████  █████ ████ █████████████
 ▒███▒▒███ ▒███  ███▒▒███ ███▒▒███ ▒▒███▒▒███▒▒███ ▒▒███ ▒▒███ ▒███ ▒▒███▒▒███▒▒███
 ▒███ ▒▒▒  ▒███ ▒███ ▒███▒███ ▒███  ▒███ ▒███ ▒███  ▒███  ▒███ ▒███  ▒███ ▒███ ▒███
 ▒███      ▒███ ▒███ ▒███▒███ ▒███  ▒███ ▒███ ▒███  ▒███  ▒███ ▒███  ▒███ ▒███ ▒███
 █████     █████▒▒██████ ▒▒████████ █████▒███ █████ █████ ▒▒████████ █████▒███ █████
▒▒▒▒▒     ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒ ▒▒▒ ▒▒▒▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒ ▒▒▒ ▒▒▒▒▒
"
    echo -e $menu_text
}

checkWP(){
  writeprotect=$(flashrom --wp-status 2>&1 | grep "disabled")
  if [[ $writeprotect == *"disabled"* ]]; then
    echo -e "FWWP is currently ${G}DISABLED${N}, continuing..."
  else
    echo -e "FWWP is currently ${N}ENABLED${N}, checking for wp range..."
    wprange=$(flashrom --wp-status 2>&1 | grep -E "range: start=0x[0-9a-f]+, len=0x00000000")
    if [[ $wprange != "" ]]; then
      echo -e "WP range allows for flashing, continuing."
    else
      echo -e "WP range non-zero, checking for HWWP."
      if [[ $(crossystem wpsw_cur) == "0" ]]; then
        echo -e "HWWP off, attempting to disable SWWP."
        flashrom --wp-disable || echo -e "WARNING: SWWP FAILED TO DISABLE! This is a known issue on ARM boards such as corsola and geralt. As HWWP is off, Modmium can still install, however WP must be disabled again once you wish to revert" && read -p "Press enter to continue, or Ctrl+C to abort."
      else
        if isti50=$(gsctool -a -I | grep AllowUnverifiedRo); then
          setting=$(echo $isti50 | awk '{print $3}')
          case $setting in
            Always)
              gsctool -a -w disable || fail "Failed to disable HWWP. Please open CCD and try again"
              crossystem wpsw_cur || grep "0" || fail "Failed to disable HWWP."
              flashrom --wp-disable || echo -e "WARNING: SWWP FAILED TO DISABLE! This is a known issue on ARM boards such as corsola and geralt. Modmium can still install because HWWP is disabled, but you may encounter issues later." && read -p "Press enter to continue, or Ctrl+C to abort."
              ;;
            Never)
              gsctool -a -I AllowUnverifiedRo:Always || fail "Failed to disable AP RO verification. Please open CCD and try again"
              gsctool -a -w disable || fail "Failed to disable HWWP. Please open CCD and try again"
              crossystem wpsw_cur || grep "0" || fail "Failed to disable HWWP."
              flashrom --wp-disable || echo -e "WARNING: SWWP FAILED TO DISABLE! This is a known issue on ARM boards such as corsola and geralt. Modmium can still install because HWWP is disabled, but you may encounter issues later." && read -p "Press enter to continue, or Ctrl+C to abort."
              ;;
            *) fail "Got an unexpected AllowUnverifiedRo value ('$setting') from gsctool. Please ask in the Discord (${Y}discord.crosbreaker.com${R}) with this exact message." ;;
          esac
        fi
        fail "HWWP and SWWP are enabled with WP range non-zero, please disable your WP by following this guide: ${G}https://crosmium.dev/HWWP${N}"
      fi
    fi
  fi
}

checkAPROV(){
  if isti50=$(gsctool -a -I | grep AllowUnverifiedRo); then
    setting=$(echo $isti50 | awk '{print $3}')
    case $setting in
      Always) echo -e "APROV is currently ${G}DISABLED${N}, continuing..." ;;
      Never) fail "APROV is currently ${R}ENABLED${N}. If you're seeing this, WP is off but APROV is on and rebooting will ${R}${UN}BRICK YOUR DEVICE${RUN}${N}.\n Disable APROV immediately by running \`gsctool -a -I AllowUnverifiedRo:always\`" ;;
      *) fail "Got an unexpected AllowUnverifiedRo value ('$setting') from gsctool. Please ask in the Discord (${Y}discord.crosbreaker.com${R}) with this exact message." ;;
    esac
  else
    echo -e "Device is not Ti50, continuing..."
  fi
}

get_largest_cros_blockdev() {
  local largest size dev_name tmp_size remo
  size=0
  command -v sfdisk >/dev/null 2>&1 || return 0
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

selUserBackup(){
  echo -e "These are the vfat drives/partitions connected to your device:"
  for drive in $(lsblk -lo NAME,FSTYPE | grep vfat | awk '{print $1}'); do
    echo /dev/$drive
  done
  echo -e "Type the drive that the signing keys [userkeys] were backed up to (/dev/sdX or sdX are acceptable)...${N}"
  read -ep "Drive: " driveloc
  driveloc="${driveloc%/}"
  if [[ $driveloc == *"/dev/"* ]]; then
    if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device...${N}" keepflag; fi
  else
    if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device...${N}" keepflag; fi
  fi
}

modmiumInstall(){
  if [[ $FLAGS_userkeys == $FLAGS_TRUE ]]; then
    BACKUP=/tmp/backupdir
    mkdir -p $BACKUP
    echo -e "These are the vfat drives/partitions connected to your device:"
    for drive in $(lsblk -lo NAME,FSTYPE | grep vfat | awk '{print $1}'); do
      echo /dev/$drive
    done
    echo -e "Type the drive that the signing keys were backed up to (/dev/sdX or sdX are acceptable)...${N}"
     read -ep "Drive: " driveloc
     driveloc="${driveloc%/}"
     if [[ $driveloc == *"/dev/"* ]]; then
      if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device...${N}" keepflag; fi
     else
       if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device...${N}" keepflag; fi
     fi
    keydir=${BACKUP}/userkeys
  else
    keydir=/usr/share/vboot/devkeys
  fi
  if ! which git &>/dev/null || ! which file &>/dev/null; then
    ensure_deps git file
  fi
  [[ $FLAGS_userkeys == $FLAGS_TRUE ]] && selUserBackup
  if [[ $QUICKINSTALL == $FLAGS_TRUE ]]; then
    echo -e "Verifying firmware..."
    DEVFW=$(vpd -i RO_VPD -g "dev_firmware")
    if [[ $DEVFW != "1" ]]; then
      fail "${R}Something went wrong! DevFW is not active, please join the discord and ask for help! (${Y}discord.crosbreaker.com${R})${D} \nIf you manually flashed DevFW, and Modmium cannot detect it, run 'vpd -i RO_VPD -s dev_firmware=1' to tell Modmium you are using DevFW.${N}" keepflag
    else
      echo -e "DevFW is enabled! Continuing..."
      sleep 1
    fi
  fi
  installCros # :whale:
}
selectBackup(){
  BACKUP=/tmp/backupdir
  mkdir -p $BACKUP
  if [[ $FLAGS_backup == $FLAGS_FALSE && "$(vpd -i RO_VPD -g dev_firmware 2>/dev/null)" == "" ]]; then
    moment=$(date +"%Y%m%d")
    intdis=$(rootdev -s -d)
    echo -e "Creating emergency backup (${intdis}p12/firmware/backup_${moment}.rom)"
    echo -e "${D}This backup will be erased if you use a recovery image, it is only for if something goes wrong during devFW flashing.${N}"
    mkdir -p /tmp/p12
    mount ${intdis}p12 /tmp/p12
    [[ $(ls /tmp/p12/firmware | grep backup) ]] || flashrom -r /tmp/p12/firmware/backup_${moment}.rom
    sync;sync;sync # don't count how many syncs are in this script 
    umount /tmp/p12
    rmdir /tmp/p12
  fi
  [[ $FLAGS_backup == $FLAGS_FALSE && $FLAGS_userkeys == $FLAGS_FALSE ]] && return
  if [[ $FLAGS_userkeys == $FLAGS_FALSE ]]; then
    cat <<EOF | xargs -0 echo -ne
Would you like to ${R}ERASE${N} an external (D)rive and backup to it, or backup to a directory? (D = drive, P = directory)
Backing up to a (D)rive is highly recommended, but if you know what you're doing, [or already have a mount (P)oint], you can use a directory
EOF
    read -ep "(d/p): " resp
    if [[ $resp =~ ^[Dd]$ ]]; then
      drivelist=$(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "$(get_largest_cros_blockdev)|loop|ram" || fail "${R}No connected drives, exiting...${N}")
      cat <<EOF | xargs -0 echo -ne
These are the drives connected to your device:
$drivelist
What drive would you like write the backup onto? Type /dev/sdX or sdX not the USB's name ${R}(THIS WILL ERASE THE DRIVE!!!!)${N}
EOF
      read -ep "Drive: " driveloc
      driveloc="${driveloc%/}"
      [[ $driveloc == *"/dev/"* ]] || driveloc="/dev/$driveloc"
      confirm_destructive "This will ERASE EVERYTHING on ${driveloc}. Are you sure this is the right drive?" \
        || fail "${R}Exiting...${N}" keepflag
      mkfs.vfat -I -F 32 $driveloc || fail "${R}Unable to wipe device, exiting...${N}"
      mkdir -p $BACKUP
      mount $driveloc $BACKUP || fail "${R}Unable to mount device, exiting...${N}"
       if ! ( [ -d ${BACKUP} ] && touch ${BACKUP}/.test ); then
        fail "${R}Unable to write to backup, exiting...${N}"
      fi
      DRIVEBACKUP=1
    elif [[ $resp =~ ^[Pp]$ ]]; then
      echo -e "What directory would you like to backup to?"
      read -ep "Dir: " BACKUP
      if ! ( [ -d ${BACKUP} ] && touch ${BACKUP}/.test ); then
        fail "${R}Unable to write to backup, exiting...${N}"
      else
        echo -e "Valid directory!"
      fi
    else
      fail "Invalid response, exiting..."
    fi
  else
    echo -e "These are the vfat drives/partitions connected to your device:"
    for drive in $(lsblk -lo NAME,FSTYPE | grep vfat | awk '{print $1}'); do
      echo /dev/$drive
    done
    echo -e "Type the drive that the signing keys were backed up to (/dev/sdX or sdX are acceptable)...${N}"
    read -ep "Drive: " driveloc
    driveloc="${driveloc%/}"
    if [[ $driveloc == *"/dev/"* ]]; then
      if ! mount $driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
    else
      if ! mount /dev/$driveloc $BACKUP; then fail "${R}Unable to mount device...${N}"; fi
    fi
    if ! ( [ -d ${BACKUP} ] && touch ${BACKUP}/.test ); then
      fail "${R}Unable to write to backup.${N}"
    fi
    DRIVEBACKUP=1
  fi
  if [[ $(df $BACKUP | awk '{print $4}' | tail -n 1) -lt 16384 ]]; then
    fail "${R}NOT ENOUGH EMPTY SPACE ON DRIVE. Exiting...${N}"
  fi
}

flashDevFW(){
  DEVFW=$(vpd -i RO_VPD -g "dev_firmware" 2>&1)
  (
    device_management_client --action=remove_firmware_management_parameters >/dev/null 2>&1 || \
    cryptohome --action=remove_firmware_management_parameters >/dev/null 2>&1
    device_management_client --action=set_firmware_management_parameters --flags=0x0 >/dev/null 2>&1 || \
    cryptohome --action=set_firmware_management_parameters --flags=0x0 >/dev/null 2>&1
  ) \
  || \
  ( initctl stop tcsd >/dev/null 2>&1
    initctl stop trunksd >/dev/null 2>&1
    tpmc clear; tpmc def 0x100a 0x28 0x12000
    tpmc write 0x100a 76 28 10 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  ) # we do this to *ensure* that FWMP is gone even if device_management_client is bugging out

  if [[ $DEVFW != 1 ]]; then
    echo -e "Making firmware backup..."
    flashrom -r $BACKUP/backup_$(date +"%Y%m%d").rom
    # flash gbb flags, devkeys, and set dev_firmware to 1 to prevent accidental reflashing :3
    if [[ $FLAGS_userkeys == $FLAGS_FALSE ]]; then
      /usr/share/vboot/bin/make_dev_ssd.sh --force -r
      /usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid $BACKUP --to /tmp/devfw.bin
      futility gbb -s /tmp/devfw.bin --flags=0xa0b1
      flashrom -w /tmp/devfw.bin || fail "DevFW failed to flash!"
    else
      /usr/share/vboot/bin/make_dev_ssd.sh --force -r --keys ${BACKUP}/userkeys
      /usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid $BACKUP --keys ${BACKUP}/userkeys --to /tmp/devfw.bin
      futility gbb -s /tmp/devfw.bin --flags=0xa0b1
      flashrom -w /tmp/devfw.bin || fail "DevFW failed to flash!"
    sync # sync because I dont trust ChromeOS
    fi
    vpd -i RO_VPD -s dev_firmware=1
  else
    fail "You are already using custom boot keys!" keepflag
  fi
  sleep 0.5

}

main(){
  clear
  logo
  cat <<EOF | xargs -0 echo -ne
This requires write protection to be disabled, and it will be checked before this script attempts anything
Checking for Firmware Write Protection...
EOF
  checkWP
  checkAPROV # Kinda useless now, no harm in keeping though!

  confirm_irreversible "Are you sure you want to flash DevFW firmware? This changes your boot keys and cannot be undone without a factory firmware restore." \
    || { echo -e "Denied! exiting.."; exit 0; }

  [[ $QUICKINSTALL == $FLAGS_FALSE ]] && echo -e "Getting backup selection..."
  selectBackup

  [[ $QUICKINSTALL == $FLAGS_FALSE ]] && echo -e "Backup selection complete, flashing DevFW..."
  flashDevFW
  if [[ $QUICKINSTALL == $FLAGS_FALSE ]]; then
    touch /tmp/.rebootpls
    cat <<EOF | xargs -0 echo -ne
If everything succeeded, you are now running DevFW!
It is highly recommended to go backup the firmware that is now in your selected drive (or directory) to the cloud, or another safe place.
${B}Please reboot your chromebook${N}. After you reboot, either recover with a Modmium image OR run this script again to INSTALL Modmium. (If you used userkeys, make sure you also use that flag when trying to Install Modmium with this script)
EOF
  else
    cat <<EOF | xargs -0 echo -ne
If everything succeeded, you are now running DevFW!
Starting Modmium install...
EOF
    sync # for good luck
    sleep 2
    modmiumInstall # we don't need to reboot because when QUICKINSTALL=1, rootfs verification on the currently booted chromeOS doesn't matter because there isn't a chance a reco image will be used, and stream.py is put in /usr/local/ instead of /root/ regardless.
  fi
  echo -e "Exiting..."
  sleep 0.5
  exit 0
}

clear
DEVFW=$(vpd -i RO_VPD -g "dev_firmware")
if [[ -f /tmp/.rebootpls ]]; then
  echo -e "Please reboot your device before running this script again!"
  exit 1
fi
if [[ "$DEVFW" -eq 1 ]]; then
  modmiumInstall
else
  main
fi
