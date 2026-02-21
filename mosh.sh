#!/bin/bash

# 99% of this was stolen from cr3nroll :3

# -- { DO NOT MODIFY } --
selected_index=0
# MILESTONE=$(cat /etc/lsb-release | grep MILESTONE | sed 's/^.*=//' )
# -----------------------

# TUI colors :D
B='\033[1;36m' 
G='\033[1;32m' 
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'    
D='\033[1;90m'


# -- TESTING FLAGS :3 --
# MILESTONE=143

# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
options=("1) Root Shell" "2) Chronos Shell" "3) Crosh" "4) Exit")
num_options=${#options[@]}
}

menu_reset

# STOLEN CODE FROM BR0KER TO GET MILESTONE :3
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
					continue;
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


selector() {
if [[ "${options[$selected_index]}" == "4) Exit" ]]; then
tput cnorm
clear
exit 0
menu_reset
full_menu
fi

if [[ "${options[$selected_index]}" == "1) Root Shell" ]]; then
tput cnorm
employ as_system bash
fi

if [[ "${options[$selected_index]}" == "2) Chronos Shell" ]]; then
tput cnorm
employ as_system "cd /home/chronos; sudo -i -u chronos" 
fi

if [[ "${options[$selected_index]}" == "3) Crosh" ]]; then
tput cnorm
employ /usr/bin/crosh.old 
fi
}
full_menu() {
clear
tput civis
while true; do
    display_menu
    read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 1 keyseq
        case "$keyseq" in
            '[A')
                selected_index=$(( (selected_index - 1 + num_options) % num_options ))
                ;;
            '[B')
                selected_index=$(( (selected_index + 1) % num_options ))
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




employ() { # this named employ to scare carbon away
    clear
    trap 'kill -2 $! >/dev/null 2>&1' INT
    (
        $@
    )
    trap '' INT
    clear
}
as_system() {
# this bypasses permissions on /rootkey preventing ssh from working
local ROOTKEY
ROOTKEY=$(cat /rootkey)
ssh-agent bash -c "echo '$ROOTKEY' | ssh-add - >/dev/null 2>&1; ssh -t -p 1337 -oStrictHostKeyChecking=no root@127.0.0.1 \"$*\""
}
menu_logo() {
    echo -ne "\033]0;MOSH\007"
 echo -e "Welcome to MOSH, the Modmium developer shell

If you got here by mistake, don't panic! Just close this tab and carry on.

This shell contains a list of utilities for performing various actions on a chromebook running Modmium.
"
}
display_menu() {
tput sc
   menu_logo



if [[ "$MILESTONE" == "" ]]; then
echo -e "${R}Uhh... how are you seeing this if ChromeOS isn't installed..?${N}"
else
if [[ "$MILESTONE" -le 130 ]]; then
echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N}, which is not officially supported by Modmium."
else
echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} (Modmium) --"
fi
fi
echo ""
for i in "${!options[@]}"; do
    if [[ $i -eq $selected_index ]]; then
        printf "\e[7m > ${options[$i]} \e[0m\n"
    else
        printf "   ${options[$i]}      \n"
    fi
done
}
clear
full_menu
tput cnorm
selector
