#!/bin/bash
# written by pilot bell

fail(){
  local ec=$?
  echo -e "$1"
  sleep 2
  [[ ! $ec -eq 0 ]] && exit $ec
  exit 1
}

# -- Pre TUI init --
stty -echo
echo -ne "\033]0;MOSH\007"
source /usr/lib/libmosh.sh

if ! which python3 &>/dev/null; then
  echo -e "${R}Dependencies not installed, installing...${N}"
  source /etc/profile # required to get emerge working in mosh
  if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    touch /mnt/stateful_partition/.devinstall_complete
  fi
  ldconfig # reload shared libraries to include python libs
fi

tarball="https://codeload.github.com/pilotbellyt-spec/ashland/tar.gz/refs/heads/main"
ashDir="/usr/local/lib/ashland"
ashConf="/home/chronos/user/.config/ashland/ashland.conf"
ashJob="/etc/init/ashland.conf"
layouts=("dwindle" "master" "grid" "monocle")

# -- FUNCTIONS --
quit() {
  clear
  tput cnorm
  exit 0
}

asChronos() {
  sudo -u chronos HOME=/home/chronos/user /usr/local/bin/ashland "$@"
}

readOption() {
  grep -E "^$1 *=" "$ashConf" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' ' | cut -d'#' -f1
}

writeOption() {
  [[ -f $ashConf && -n $2 ]] || return
  sed -i -E "s|^($1[[:space:]]*=[[:space:]]*)[^[:space:]#]*|\\1$2|" "$ashConf"
  chown chronos:chronos "$ashConf"
}

checkStatus() {
  [[ -f /usr/local/bin/ashland ]] && installed=1 || installed=0
  asChronos state &>/dev/null && running=1 || running=0
  [[ -f $ashJob ]] && autostart=1 || autostart=0
  grep -q '^--remote-debugging-port=' /etc/chrome_dev.conf 2>/dev/null && cdp=1 || cdp=0
  layout=$(readOption layout)
  [[ -z $layout ]] && layout="dwindle"
  gapsIn=$(readOption gaps_in)
  gapsOut=$(readOption gaps_out)
}

installAshland() {
  clear
  echo -e "Downloading ashland..."
  rm -rf /tmp/ashland-src
  mkdir -p /tmp/ashland-src
  curl -sL "$tarball" | tar xz -C /tmp/ashland-src --strip-components=1 || fail "${R}Download failed, connect to the internet first.${N}"
  rm -rf "$ashDir"
  mkdir -p "$ashDir"
  cp -r /tmp/ashland-src/. "$ashDir"
  rm -rf /tmp/ashland-src
  echo -e "Installing..."
  HOME=/home/chronos/user bash "$ashDir/install.sh" &>/dev/null || fail "${R}Install failed.${N}"
  chown -R chronos:chronos "$ashDir" /home/chronos/user/.config/ashland
  if [[ $cdp == 0 ]]; then
    echo -e "${Y}ashland needs Chrome's debugging port, which requires a UI restart.${N}"
    bash "$ashDir/enable-cdp.sh" --no-restart &>/dev/null || fail "${R}Could not edit /etc/chrome_dev.conf.${N}"
    echo -e "${G}Installed!${N} Restarting the UI, MOSH will close."
    sleep 3
    restart ui
  fi
  echo -e "${G}Installed!${N}"
  sleep 1.67
  menu_reset
  full_menu
}

uninstallAshland() {
  clear
  echo -e "Removing ashland..."
  [[ $running == 1 ]] && asChronos quit &>/dev/null
  rm -f /usr/local/bin/ashland "$ashJob"
  rm -rf "$ashDir"
  echo -e "${G}Removed.${N} Chrome's debugging port was left enabled, disable it under Feature Toggles if you want."
  sleep 2.5
  menu_reset
  full_menu
}

toggleAshland() {
  clear
  if [[ $running == 1 ]]; then
    echo -e "Stopping ashland..."
    asChronos quit &>/dev/null
  else
    echo -e "Starting ashland..."
    asChronos start &>/dev/null
  fi
  sleep 1.67
  menu_reset
  full_menu
}

toggleAutostart() {
  clear
  if [[ $autostart == 1 ]]; then
    echo -e "Disabling autostart..."
    rm -f "$ashJob"
  else
    echo -e "Enabling autostart..."
    printf 'description "ashland tiling window manager"\nstart on started ui\nstop on stopping ui\nrespawn\nrespawn limit 10 60\nexec sudo -u chronos HOME=/home/chronos/user /usr/local/bin/ashland daemon --keys\n' > "$ashJob"
    chmod 644 "$ashJob"
  fi
  sleep 1.67
  menu_reset
  full_menu
}

cycleLayout() {
  clear
  checkStatus
  for i in "${!layouts[@]}"; do
    if [[ "${layouts[$i]}" == "$layout" ]]; then
      layout="${layouts[$(((i + 1) % ${#layouts[@]}))]}"
      break
    fi
  done
  echo -e "Switching to ${B}$layout${N}..."
  writeOption layout "$layout"
  [[ $running == 1 ]] && asChronos layout "$layout" &>/dev/null
  sleep 1
  menu_reset
  full_menu
}

cycleGaps() {
  clear
  checkStatus
  case "$gapsIn" in
    0) gapsIn=6; gapsOut=12 ;;
    6) gapsIn=12; gapsOut=24 ;;
    *) gapsIn=0; gapsOut=0 ;;
  esac
  echo -e "Setting gaps to ${B}$gapsIn/$gapsOut${N}..."
  writeOption gaps_in "$gapsIn"
  writeOption gaps_out "$gapsOut"
  [[ $running == 1 ]] && asChronos gaps "$gapsIn" "$gapsOut" &>/dev/null
  sleep 1
  menu_reset
  full_menu
}

# -- MAIN SCRIPT --
tput civis

menu_reset() {
  menuText="\nTiling Window Manager\n"
  options=()
  checkStatus
  if [[ $installed == 0 ]]; then
    options+=("Install ashland")
    functions=("installAshland" "quit")
  else
    if [[ $running == 1 ]]; then
      options+=("Toggle ashland [ON]")
    else
      options+=("Toggle ashland [OFF]")
    fi
    if [[ $autostart == 1 ]]; then
      options+=("Autostart ashland on reboot [ON]")
    else
      options+=("Autostart ashland on reboot [OFF]")
    fi
    options+=("Layout [$layout]")
    options+=("Gaps [$gapsIn/$gapsOut]")
    options+=("Uninstall ashland")
    functions=("toggleAshland" "toggleAutostart" "cycleLayout" "cycleGaps" "uninstallAshland" "quit")
  fi
  options+=("Exit")
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
