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
  echo -en "${G}Enter network interface (most likely "wlan0" if on wifi): ${N}"
  read -re target_device
  default_mac="$(ip -j link show $target_device | jq -r '.[0].permaddr')"
  fail "$(set_addr $default_mac $target_device)"
  stty -echo
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
  options=("${G}Randomize the MAC address${N}" "${G}Set a custom MAC address${N}" "${G}Reset MAC address to device default${N}" "Go back")
  functions=("randomize" "set_custom" "reset_default" "quit")
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

${Y}Custom MAC addresses reset on reboot.${N}
EOF
  )
  num_options=${#options[@]}
}
menu_reset
clear
full_menu
tput cnorm
selector
