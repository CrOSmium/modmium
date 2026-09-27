#!/bin/bash
# written by ReznorsRevenge

source /usr/lib/libmosh.sh

fail() {
  echo -e "$1"
  sleep 3
  exit 1
}

interfaces="$(ip -j link show | jq '[ .[].ifname | select(test("^lo$|^vmtap") | not) ]')"
current_addrs="$(ip -j link show | jq -r '.[] | select(.ifname | test("^lo$|^vmtap") | not) | "\(.ifname) - \(.address)"')"
perm_addrs="$(ip -j link show | jq -r '.[] | select(.ifname | test("^lo$|^vmtap") | not) | "\(.ifname) - \(.permaddr // .address)"')"
[[ -e "/etc/init/mac-randomize.conf" ]] && startup_random=true || startup_random=false

gen_random() {
  printf '%x' $((RANDOM%16))
  tr -dc '26ae' < /dev/urandom | head -c 1
  openssl rand -hex 5 | sed 's/\(..\)/:\1/g'
}

randomize() {
  fail "$(set_addr "$(gen_random)")"
}

set_custom() {
  stty echo
  echo -en "${G}Enter custom MAC address: ${N}"
  read -re custom_mac
  fail "$(set_addr $custom_mac)"
  stty -echo
}

reset_default() {
  stty echo
  $startup_random && echo -e "${Y}Note: Your MAC address will still be randomized at startup!${N}"
  echo -en "${G}Enter network interface (most likely "wlan0" if on wifi): ${N}"
  read -re target_device
  default_mac="$(ip -j link show $target_device | jq -r '.[0].permaddr')"
  fail "$(set_addr $default_mac $target_device)"
  stty -echo
}

macConf=$(cat <<'EOF'
description "Modmium MAC address auto-randomizer"

start on started shill
task

script
  target_device="%TARGET_DEVICE%"

  for i in $(seq 1 10); do
    ip link show "$target_device" > /dev/null 2>&1 && break
    sleep 1
  done
  ip link show "$target_device" > /dev/null 2>&1 || exit 0

  ip link set dev "$target_device" down
  ip link set dev "$target_device" address "$(printf '%x' $((RANDOM%16)))$(tr -dc '26ae' < /dev/urandom | head -c 1)$(openssl rand -hex 5 | sed 's/\(..\)/:\1/g')"
  ip link set dev "$target_device" up

  logger -t modmium "Set $target_device MAC to new randomized address"
end script
EOF
)

startup_randomize() {
  stty echo
  if ! $startup_random; then
    echo -en "${G}Enter network interface (most likely "wlan0" if on wifi): ${N}" >&2
    read -re target_device
    stty -echo
    if [[ "$target_device" == "lo" ]] || [[ ! -d "/sys/class/net/$target_device" ]]; then
      fail "${R}Invalid network device...${N}"
    else
      echo "${macConf//%TARGET_DEVICE%/$target_device}" > /etc/init/mac-randomize.conf
      # make sure initctl sees job
      initctl reload-configuration
      startup_random=true
      fail "${G}MAC address for interface $target_device will randomize on startup.${N}"
    fi
  else
    echo -en "${Y}Disable MAC address randomization at startup? [y/N]: ${N}"
    read -re disableYN
    stty -echo
    if [[ "$disableYN" == "y" ]]; then
      rm /etc/init/mac-randomize.conf
      initctl reload-configuration
      startup_random=false
      fail "${G}MAC address will no longer randomize at startup.${N}"
    else
      fail "${R}Aborting...${N}"
    fi
  fi
}

set_addr() {
  stty echo
  if [[ ! "$1" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
    echo "${R}Invalid custom MAC address...${N}"
    return 1
  fi
  if [[ "$#" -eq 2 ]]; then
    target_device=$2
  else
    echo -en "${G}Enter network interface (most likely "wlan0" if on wifi): ${N}" >&2
    read -re target_device
  fi
  if [[ "$target_device" == "lo" ]] || [[ ! -d "/sys/class/net/$target_device" ]]; then
    echo "${R}Invalid network device...${N}"
    return 1
  fi
  ip link set dev $target_device down >/dev/null 2>&1 || local failed=1
  ip link set dev $target_device address $1 >/dev/null 2>&1 || local failed=1
  ip link set dev $target_device up >/dev/null 2>&1 || local failed=1
  stty -echo
  if [[ $failed -eq 1 ]]; then
    echo "${R}Failed to set custom address (it's most likely invalid).${N}"
    return 1
  else
    echo "${G}Successfully set custom MAC address: $1${N}"
    return 0
  fi
}

menu_reset() {
  options=("${G}Randomize the MAC address${N}" "${G}Set a custom MAC address${N}" "${G}Reset MAC address to device default${N}" "${G}Toggle MAC address randomization at startup${N}" "Go back")
  functions=("randomize" "set_custom" "reset_default" "startup_randomize" "quit")
  menuText=$(cat <<EOF
${P}+##############################################+
| MAC Address Changer                          |
| -------------------------------------------- |
| Modifies/randomizes your MAC address         |
+##############################################+${N}
${D}(Hit Ctrl+C to return to MOSH)${N}

CURRENT MAC ADDRESSES:
$current_addrs

DEFAULT MAC ADDRESSES (these don't change):
$perm_addrs
EOF
  )
  if $startup_random; then
    menuText+=$'\n\n'"${Y}Your MAC address is set to randomize at startup.${N}"
  else
    menuText+=$'\n\n'"${Y}Custom MAC addresses will be cleared on reboot!${N}"
  fi
  num_options=${#options[@]}
}
menu_reset
clear
full_menu
tput cnorm
selector
