#!/bin/bash
# written by DMD
VERSION="2.0.0(a)"

# -- FLAGS --
BROKER_PATH="broker.sh" # if you put broker in another spot, put the path here :3
BROKER_ENABLED="false"  # enable or disable launching br0ker for supported versions
INSIDE_SHIM="false" # set to 'true' if you want bash as an option and reboot on exit
PAYLOAD_MODE="true" # set to 'true' if you do not want deprovision/unenroll as an option
# -----------


# -- TESTING FLAGS --
# FLAG_MILESTONE=


# -- modified libmosh --

selected_index=0

# TUI colors :D
B='\033[38;5;45m'
G='\033[38;5;46m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
P='\033[38;5;135m'
N='\033[0m'
D='\033[1;90m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline


milestone() { 
    CROS_DEV=$(get_largest_cros_blockdev)
    MNT=$(mktemp -d)
    for i in 3 5; do
        mount -o ro "$(format_part_number "$CROS_DEV" "$i")" "$MNT" >/dev/null 2>&1 || continue
        # end of stolen code
        NEW_MILESTONE=$(cat "$MNT/etc/lsb-release" | grep "CHROMEOS_RELEASE_CHROME_MILESTONE" | sed 's/^.*=//')
        if [ ! -z "$NEW_MILESTONE" ]; then
            MILESTONE=$NEW_MILESTONE
        fi
        umount "$MNT"
    done
if [[ "$FLAG_MILESTONE" != "" ]]; then
    MILESTONE=$FLAG_MILESTONE
fi
}

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
            continue
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

full_menu() {
	clear
	stty -echo
	tput civis
	tput sc
	while true; do
		tput rc
    	display_menu
    	read -rsn1 key
    	if [[ "$key" == $'\x1b' ]]; then
        	read -rsn2 -t 0.1 keyseq
        	case "$keyseq" in
            	'[A') selected_index=$(((selected_index - 1 + num_options) % num_options)) ;;
            	'[B') selected_index=$(((selected_index + 1) % num_options)) ;;
        	esac
    	elif [[ "$key" =~ [0-9a-zA-Z] ]]; then
        	for i in "${!options[@]}"; do
            	clean_opt=$(echo "${options[$i]}" | sed 's/\x1b\[[0-9;]*m//g')
            	if [[ "${clean_opt,,}" == "${key,,}"* ]]; then
                	selected_index=$i
                	break
            	fi
        	done
    	elif [[ "$key" == "" ]]; then
        	selector
        	break
    	fi
    	tput rc
	done
	tput cnorm
	stty echo
}


selector() {
echo ""
# left empty on purpose so it can be properly implemented in the script using libmosh
}

menu_logo() {
    echo -e "
 ██████╗██████╗ ██████╗ ███╗   ██╗██████╗  ██████╗ ██╗     ██╗     
██╔════╝██╔══██╗╚════██╗████╗  ██║██╔══██╗██╔═══██╗██║     ██║     
██║     ██████╔╝ █████╔╝██╔██╗ ██║██████╔╝██║   ██║██║     ██║     
██║     ██╔══██╗ ╚═══██╗██║╚██╗██║██╔══██╗██║   ██║██║     ██║     
╚██████╗██║  ██║██████╔╝██║ ╚████║██║  ██║╚██████╔╝███████╗███████╗
 ╚═════╝╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝
"
    echo -e "| By OSmium (CrOSmium on Github) | v$VERSION"
    echo ""
}

employ() { # this named employ to scare fanxql away
	clear
  trap 'kill -2 $! >/dev/null 2>&1' INT
  	(
    	$@
    )
  trap '' INT
  clear
}

runscript() {
	stty echo
	tput cnorm
	echo "$1"
	employ "$1"
	menu_reset
	full_menu
}

display_menu() {
	tput sc
	menu_logo
	case "$writeprotect" in
	    *"disabled"*)
	        echo -e "You currently have Firmware Write Protection set to ${R}(DISABLED)${N}, all features *should* work properly. Have fun :D"
	        ;;
	    *)
	        echo -e "You currently have Firmware Write Protection set to ${G}(ENABLED)${N}, you will be ${R}unable${N} to modify your current enrollment info until you disable it [${G}https://crosmium.dev/FWWP${N}]!"
	        ;;
	esac
	case "$MILESTONE" in
	    "")
	        echo -e "${R}Could not get ChromeOS milestone, is ChromeOS installed?${N}"
	        ;;
	    *)
	        if [[ "$MILESTONE" -ge 143 ]]; then
	            echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N}, therefore your version ${R}does not have an available unenrollment${N}. Try downgrading if possible!"
	        else
	            echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} --"
	        fi
	        ;;
	esac
	echo ""
	for i in "${!options[@]}"; do
		if [[ $i -eq $selected_index ]]; then
			printf "\e[7m > ${options[$i]} \e[0m\n"
		else
			printf "   ${options[$i]}      \n"
		fi
	done
}

# ----------

# -- { DO NOT MODIFY } --
selected_index=0
writeprotect=$(flashrom --wp-status | grep disabled)
factoryserial=$(vpd -i RO_VPD -g "factory_serial_number")
stateful=$(format_part_number "$cros_dev" 1)
if [[ "$factoryserial" == "" ]]; then
    factorysaved="1"
fi
# ----------------------

# -- MENU FUNCTIONS --
savecurrentkeys() {
	clear
	menu_logo
	sleep 0.3
	echo -e "Enter name to save enrollment keys as"
	tput cnorm
	KEYNAMEC() {
		echo -ne "Key name: "
		read KEYNAME
		sleep 0.4
		if [[ "$KEYNAME" =~ [[:space:]_] ]]; then
			echo -e "(Invalid Keyname! Cannot be contain a space OR underscore!)"
			KEYNAMEC
		fi
		if [[ $KEYNAME = "" ]]; then
			echo -e "(Invalid Keyname! Cannot be empty!)"
			KEYNAMEC
		fi
	}
	KEYNAMEC
	echo -e "Setting enrollment keyname to '$KEYNAME'"
	sleep 0.2
	echo -e "Reading VPD..."
	sleep 0.67
	STABLEDEV=$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")
	echo -e "Read stable_device_secret!"
	sleep 0.4
	SERIAL=$(vpd -i RO_VPD -g "serial_number")
	echo -e "Read serial_number!"
	sleep 0.8
	echo ""
	echo -e "Are you sure you want to save the key under the name '$KEYNAME' for the serial number '$SERIAL'?"
	echo -ne "(Y/N): "
	read YESNT
	if [[ "${YESNT}" = [Yy] ]]; then
		echo -e "Saving keys (to RW_VPD)..."
		vpd -i RW_VPD -s "saved_"$KEYNAME"_stable_device_secret"="$STABLEDEV"
		sleep 0.3
		vpd -i RW_VPD -s "saved_"$KEYNAME"_serial_number"="$SERIAL"
		sleep 0.3
		echo -e "Keys written to VPD!"
		sleep 0.8
	else
		echo -e "Declined!"
	fi
	sleep 1
	echo -e "Returning to menu..."
	sleep 0.4
	menu_reset
}

genkeys() {
	clear
	menu_logo
    echo -e "Would you like to generate and save new Enrollment Keys? (Does not override currently selected keys)"
    tput cnorm
    echo -ne "(Y/N): "
    read YESNT2
    if [[ "${YESNT2}" = [Yy] ]]; then
        echo -e "Generating new Keys..."
        gensdev=$(openssl rand -hex 32)
        echo -e "Generated stable_device_secret: '$gensdev'"
        echo -e "Would you like to have your serial number auto-generated, or make one yourself? (A/M) [A = Auto, M = Manual]"
        read -r -n 1 -p "(Press A or M to continue)" snauto
        if [[ "${snauto}" == [Aa] ]]; then
            echo -e "\nGenerating serial number..."
            sleep 0.67
            # super mega cool serial number generator
            KEYNAME="$(printf 'CR%s%s%s' \
    		  "$(openssl rand -hex 16 | tr -dc '0-9' | head -c1)" \
   			  "$(openssl rand -base64 64 | tr -dc 'A-NP-Z A-NP-Z A-NP-Z 0-9' | tr -d ' ' | head -c4)" \
    		  "$(openssl rand -hex 16 | tr -dc '0-9' | head -c1)")"
        else
            echo -e "What do you want your serial number to be?"
        	currentsn=$(vpd -i RO_VPD -g "serial_number")
            echo -e "Your currently set one is: '$currentsn'"
            echo -e "Warning: Setting your serial number or Keyname blank WILL corrupt your enrollment keys"
            KEYNAMESN() {
                echo -ne "Serial Number: "
                read KEYNAME
                sleep 0.4
                if [[ "$KEYNAME" =~ [[:space:]_] ]]; then
                    echo -e "(Invalid Keyname! Cannot be contain a space OR underscore!)"
                    KEYNAMESN
                fi
                if [[ $KEYNAME = "" ]]; then
                    echo -e "(Invalid Keyname! Cannot be empty!)"
                    KEYNAMESN
                fi
            }
            KEYNAMESN
            sleep 0.67
        fi
        echo ""
        echo -e "You want your new serial number to be '$KEYNAME'?"
        echo -ne "(Y/N): "
        read SCONFIRM
        if [[ "${SCONFIRM}" = [Yy] ]]; then
            echo -e "What would you like to name these keys? (NO SPACES)"
            SKNAME() {
                echo -ne "Name: "
                read SKNAMES
                SKNAME=$SKNAMES
                if [[ "$SKNAME" =~ [[:space:]_] ]]; then
                    echo -e "(Invalid Keyname! Cannot be contain a space OR underscore!)"
                    SKNAME
                fi
                if [[ $SKNAME = "" ]]; then
                    echo -e "(Invalid Keyname! Cannot be empty!)"
                    SKNAME
                fi
            }
            SKNAME
            sleep 0.4
            echo -e "Saving new stable_device_secret and serial_number('$KEYNAME') as '$SKNAME'..."
            vpd -i RW_VPD -s "saved_"$SKNAME"_stable_device_secret"="$gensdev"
            vpd -i RW_VPD -s "saved_"$SKNAME"_serial_number"="$KEYNAME"
            sleep 0.1
            echo -e "Finished!"
        else
            echo -e "Cancelled!"
           fi

    else
        echo -e "Declined!"
    fi
    sleep 1
    echo -e "Returning to menu..."
    sleep 0.4
    menu_reset
    full_menu 
}

loadsavedkeys() {
	clear
	menu_logo
	echo -e "Getting keys..."
	mapfile -t KEYNAMES < <(vpd -i RW_VPD -l | grep '"saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
	#   mapfile -t KEYNAMES < <(echo -e "saved_test" "saved_test_serial" | grep '^saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
	clear
	menu_logo
	echo -e "-- Load saved enrollment keys --"
	echo -e "\nCurrently active serial number: '$(vpd -i RO_VPD -g "serial_number")'"
	echo ""
	if [[ ${#KEYNAMES[@]} -eq 0 ]]; then
		echo -e "No Keys found!"
		sleep 2
		clear
		menu_reset
		full_menu
	else
		options=("-- RETURN TO MENU --" ${KEYNAMES[@]})
		num_options=${#options[@]}
	
		PS3=$'\nSelection: '
		select key in "${options[@]}"; do
			case "$key" in
			"-- RETURN TO MENU --")
				menu_reset
				full_menu
				;;
			"")
				echo "Invalid selection, try again."
				;;
			*)
				echo -e "(Selected '$key')"
				echo -e "\n${R}Warning: Setting your enrollment keys is highly destructive, I recommend saving your factory ones before you select any keys.${N}\n\n(This script will attempt to back them up automatically if you haven't, but I still highly recommend doing it manually)\n"
				read -r -n 2 -s -p "Double click Y to continue, or hold any other key to exit..." confirmation
				if [[ "$confirmation" != "yy" ]]; then
					menu_reset
					full_menu
				fi
				clear
				menu_logo
	
				if [[ "$(vpd -i RO_VPD -g "factory_stable_device_secret")" == "" ]]; then
					vpd -i RO_VPD -s "factory_stable_device_secret"="$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")"
					echo -e "if you see this that means that you don't have your factory SDS (stable_device_secret) backed up, It will be backed up in the next step."
				else
					echo -e "Found valid factory entry (SDS)!"
				fi
				if [[ "$(vpd -i RO_VPD -g "factory_serial_number")" == "" ]]; then
					vpd -i RO_VPD -s "factory_serial_number"="$(vpd -i RO_VPD -g "serial_number")"
					echo -e "if you see this that means that you don't have your factory SN backed up, It will be backed up in the next step."
				else
					echo -e "Found valid factory entry (SN)!"
				fi
				sleep 1.5
				overrideSet() {
					clear
					trap 'echo -e "\nWrite cancelled, no keys were written!" && sleep 2 && menu_reset && full_menu ' SIGINT
					echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					sleep 1.5
					clear
					echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "Writing in: 3"
					sleep 1.5
					clear
					echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "Writing in: 2"
					sleep 1.5
					clear
					echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "Writing in: 1"
					sleep 2
					clear
	
					echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "${R}Writing keys...${N}"
					sleep 0.8
					clear
					menu_logo
					echo -e "Checking factory info..."
					sleep 1.7
					if [[ "$(vpd -i RW_VPD -g "factory_backup")" != "2" ]]; then
						echo -e "Backing up factory info..."
						sleep 1.7
						if [[ "$(vpd -i RO_VPD -g "factory_stable_device_secret")" == "" ]]; then
							vpd -i RO_VPD -s "factory_stable_device_secret"="$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")"
							vpd -i RW_VPD -s "factory_backup"="$(($(vpd -i RW_VPD -g "factory_backup") + 1))"
							echo -e "Wrote factory info! (SDS)"
						fi
						if [[ "$(vpd -i RO_VPD -g "factory_serial_number")" == "" ]]; then
							vpd -i RO_VPD -s "factory_serial_number"="$(vpd -i RO_VPD -g "serial_number")"
							vpd -i RW_VPD -s "factory_backup"="$(($(vpd -i RW_VPD -g "factory_backup") + 1))"
							echo -e "Wrote factory info! (SN)"
						fi
					fi
					echo -e "Writing keys to RO_VPD..."
					vpd -i RO_VPD -s "serial_number"="$(vpd -i RW_VPD -g "saved_${key}_serial_number")"
					vpd -i RO_VPD -s "stable_device_secret_DO_NOT_SHARE"="$(vpd -i RW_VPD -g "saved_${key}_stable_device_secret")"
					echo -e "Keys written to VPD!"
					sleep 1.5
					menu_reset
					full_menu
				}
				overrideSet
				menu_reset
				full_menu
				;;
			esac
		done
	fi
}

importkeys() { 
	clear
	menu_logo
	echo -e "Import Enrollment Info (from a file)"
	echo -e "${R}THIS WILL OVERWRITE YOUR ENTIRE VPD WITH THE CONTENTS OF THE FILES YOU PROVIDE ${N}"
	echo -e "\nEnter directory to import from (must contain RO.vpd and RW.vpd):"
	echo -ne "Directory: "
	read impdirec
	if [[ -d "$impdirec" ]]; then
		if [[ -f "$impdirec/RO.vpd" ]] && [[ -f "$impdirec/RW.vpd" ]]; then
			echo -e "Importing VPD from '$impdirec/RO.vpd' and '$impdirec/RW.vpd'... ${R}[THIS MAY TAKE A WHILE]${N}"

			sudo vpd -i RW_VPD -l >RW_backup.txt # this is to make sure you can recover if my sh1tty script fucks up
			sudo vpd -i RO_VPD -l >RO_backup.txt
			sleep 1
			echo -e "Importing RW_VPD..."
			sudo vpd -i RW_VPD -O
			while IFS= read -r line; do
				clean_line=$(echo "$line" | tr -d '"')
				sudo vpd -i RW_VPD -s "$clean_line"
			done <"$impdirec/RW.vpd"
			echo -e "Imported RW_VPD!"
			sleep 1.6
			echo -e "Importing RO_VPD..."
			sudo vpd -i RO_VPD -O
			while IFS= read -r line; do
				clean_line=$(echo "$line" | tr -d '"')
				sudo vpd -i RO_VPD -s "$clean_line"
			done <"$impdirec/RO.vpd"
			menu_reset
			full_menu
		else
			echo -e "File not found! Returning to menu..."
			sleep 1.2
			menu_reset
			full_menu
		fi
	fi
}

editkeys() {
	clear
	menu_logo
	echo -e "Getting keys..."
	mapfile -t KEYNAMES < <(vpd -i RW_VPD -l | grep '"saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
	#   mapfile -t KEYNAMES < <(echo -e "saved_test" "saved_test_serial" | grep '^saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
	clear
	menu_logo
	echo -e "\n\nCurrently active serial number: '$(vpd -i RO_VPD -g "serial_number")'"
	echo -e "Select a key to ${R}DELETE${N} from the saved enrollment keys."
	echo ""
	sleep 0.2
	if [[ ${#KEYNAMES[@]} -eq 0 ]]; then
		echo -e "No Keys found!"
		sleep 1.2
		clear
		menu_reset
		full_menu
	else
		options=("-- RETURN TO MENU --" ${KEYNAMES[@]})
		num_options=${#options[@]}

		PS3=$'\nSelection: '
		select key in "${options[@]}"; do
			case "$key" in
			"-- RETURN TO MENU --")
				menu_reset
				full_menu
				;;
			"")
				echo "Invalid selection, try again."
				;;
			*)
				echo -e "(Selected '$key')"
				echo -e "\n${R}Warning: This will ${R}erase${N} the selected keys from the saved enrollment keys PERMANENTLY${N}\n"
				read -r -n 2 -s -p "Double click Y to continue, or hold any other key to exit..." confirmation
				if [[ "$confirmation" != "yy" ]]; then
					menu_reset
					full_menu
				fi	
				clear
				menu_logo
				sleep 0.2
				overrideSet2() {
					clear
					trap 'echo -e "\nErase cancelled, no keys were deleted!" && sleep 2 && menu_reset && full_menu ' SIGINT
					echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					sleep 1.5
					clear
					echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "Erasing in: 3"
					sleep 1.5
					clear
					echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "Erasing in: 2"
					sleep 1.5
					clear
					echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "Erasing in: 1"
					sleep 2
					clear

					echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE${N}"
					echo -e "${R}Writing keys...${N}"
					sleep 0.8
					clear
					menu_logo
					echo -e "Erasing selected keys from RW_VPD..."
					sleep 1
					vpd -i RW_VPD -d "saved_${key}_serial_number"
					vpd -i RW_VPD -d "saved_${key}_stable_device_secret"
					sleep 0.5
					echo -e "Keys erased from RW_VPD successfully!"
					sleep 2
					menu_reset
					full_menu
				}
				overrideSet2
				menu_reset
				full_menu
				;;
			esac
		done
	fi
}

backupvpd() {
	clear
 	menu_logo
	echo -e "Backup Enrollment Info"
	echo ""
	echo -e "Where would you like to backup your VPD to? (makes a new directory '/vpd/' underneath the selected one)"
	echo -ne "Directory: "
	read sdirec
	sleep 0.67
	if [[ -d "$sdirec" ]]; then
		vpd -i RO_VPD -l
		sleep 0.67
		vpd -i RW_VPD -l
		sleep 0.67
		mkdir "$sdirec/vpd"
		vpd -i RO_VPD -l >$sdirec/vpd/RO.vpd
		vpd -i RW_VPD -l >$sdirec/vpd/RW.vpd
		echo -e "Copy complete, Validating..."
		if [[ -f "$sdirec/vpd/RO.vpd" ]]; then
			echo -e "Validated!"
			sleep 0.67
			echo -e "Backup complete! Returning to menu..."
			sleep 3.2
			menu_reset
			full_menu
		else
			echo ""
			echo -e "Validation failed, check if you're in the correct environment, or if the directory is writeable."
			sleep 2
			echo -e "Returning to menu..."
			sleep 1
			menu_reset
			full_menu
		fi
	else
		echo -e "Not a valid directory! Returning to menu..."
		sleep 1
		menu_reset
		full_menu
	fi
}
restorefactoryinfo() {
	clear
	menu_logo
	echo -e "Are you sure you want to restore saved enrollment keys from factory? This will overwrite your currently active keys."
	echo -ne "(Y/N): "
	read YESNT3
	if [[ "${YESNT3}" = [Yy] ]]; then
		if [[ "$(vpd -i RO_VPD -g "factory_stable_device_secret")" == "$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")" ]]; then
			echo -e "You are already using your factory enrollment keys :P\n\n Returning to menu..."
			sleep 2
			menu_reset
			full_menu
		fi
	else
		echo -e "Declined! Returning to menu..."
		sleep 0.8
		menu_reset
		full_menu
	fi
	echo -e "Restoring factory enrollment keys..."
	vpd -i RO_VPD -s "stable_device_secret_DO_NOT_SHARE"="$(vpd -i RO_VPD -g "factory_stable_device_secret")"
	sleep 0.4
	vpd -i RO_VPD -s "serial_number"="$(vpd -i RO_VPD -g "factory_serial_number")"
	sleep 0.4
	echo -e "Restored enrollment keys successfully! Returning to menu..."
	menu_reset
	full_menu
}
firstfactorybackup() {
	clear
	menu_logo
	echo -e "Backup Factory Enrollment Info"
	echo ""
	echo -e "${R}This is irreversible${N}\n\n${G}This will save these two keys: 'factory_serial_number' as '$(vpd -i RO_VPD -g "serial_number")' and 'factory_stable_device_secret' as '$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")'${N}"

	read -r -n 1 -p "Press Y to continue, or press any key to exit..." yesnts

	if [[ "$yesnts" == "y" ]]; then
		echo -e "\n\nSaving factory enrollment info to RO_VPD..."
		wrotekey=0
		sleep 0.67
		if [[ "$(vpd -i RO_VPD -g "factory_serial_number")" == "" ]]; then
			vpd -i RO_VPD -s "factory_serial_number"="$(vpd -i RO_VPD -g "serial_number")"
			echo -e "${G}Written!${N}"
			wrotekey=$(($wrotekey + 1))
		else
			echo -e "Key (factory_serial_number) already saved, no need to write!"
			wrotekey=$(($wrotekey + 1))
		fi
		sleep 0.67
		if [[ "$(vpd -i RO_VPD -g "factory_stable_device_secret")" == "" ]]; then
			if [[ "$wrotekey" == "1" ]]; then
				vpd -i RO_VPD -s "factory_stable_device_secret"="$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")"
				echo -e "${G}Written!${N}"
				wrotekey=$(($wrotekey + 1))
			else
				echo -e "Backup incomplete! Please make a support ticket in the Discord, or fix it yourself by running these commands when your factory info is CONFIRMED active."
				echo -e "vpd -i RO_VPD -d "factory_stable_device_secret""
				echo -e "vpd -i RO_VPD -d "factory_serial_number""
				echo -e "vpd -i RW_VPD -d "factory_backup""
				echo -e "Running these WILL wipe your currently backed up factory info!"
			fi
		else
			echo -e "Key (factory_stable_device_secret) already saved, no need to write!"
		fi
		sleep 0.67
		[[ $wrotekey == 2 ]] && vpd -i RW_VPD -s "factory_backup"="2"
		if [[ "$wrotekey" != 2 ]]; then
			echo -e "An error may have occured in your backup, please verify your RO_VPD manually below"
			vpd -i RO_VPD -l
			echo -e "\nIf both factory entries are still there, or did save correctly, ${B}please press enter to continue${R}\nIf they did not, please stay on this screen and make a support ticket in the Discord."
			read -r
		fi
		echo -e "Enrollment info backed up under 'factory_serial_number' and 'factory_stable_device_secret'!\nReturning to menu..."
		sleep 4
		menu_reset
		full_menu
	else
		menu_reset
		full_menu
	fi
}
deprovision() {
	clear
	menu_logo
	echo -e "Disable Enrollment (Deprovision/Unenroll)"
	echo -e "Getting version milestone..."

	sleep 0.67
	if [[ "$MILESTONE" == "" ]]; then
		echo -e "${R}Could not get milestone version, is ChromeOS installed?${N}"
		sleep 2.6
		echo -e "Returning to menu..."
		menu_reset
		full_menu
	fi
	echo -e "ChromeOS milestone: R$MILESTONE"

	if [[ "$MILESTONE" -le 111 ]]; then
		echo -e "Why are you using Cr3nroll on R$MILESTONE q-q"
		echo -e "Disabling Enrollment (R111 and below [CHECK_ENROLLMENT=0])..."
		vpd -i RW_VPD -s "block_devmode"="0"
		vpd -i RW_VPD -s "check_enrollment"="0"
		sleep 4
		menu_reset
		full_menu
	else
		if [[ "$MILESTONE" -ge 148 ]]; then
			echo -e "\n${R}Sorry, no unenrollment found for your version (yet), try downgrading if you can!${N}"
			sleep 0.67
			echo -e "Returning to menu..."
			sleep 3.5
		else
			if [[ "$MILESTONE" -ge 106 && "$MILESTONE" -le 132 ]]; then
				echo -e "Your version supports Br0ker, launching it now!"
				if [[ "$BROKER_ENABLED" == "true" ]]; then
					exec bash "$BROKER_PATH"
				else
					sleep 0.67
					echo -e "${R}Sorry, Br0ker support is disabled, checking for Quicksilver instead...${N}"
					sleep 2.6
					if [[ "$MILESTONE" -ge 125 ]]; then
						echo -e "\nYour version supports ${G}Quicksilver${N}! (you are using R$MILESTONE, which supports Br0ker, but it is disabled.)"
						echo ""
						echo -e "\n${R}Warning: This will prevent editing enrollment configs and enrolling until Quicksilver is removed.) [ONLY WORKS BELOW R143]\n${N}"
						echo -e "If you powerwash after updating past R142 you will be re-enrolled!"
						read -r -n 2 -s -p "Double click Y to continue, or hold any other key to exit..." confirmation
						if [[ "$confirmation" != "yy" ]]; then
							menu_reset
							full_menu
						fi
						echo -e "\nDisabling Enrollment..."
						sleep 1
						vpd -i RW_VPD -s "re_enrollment_key"="$(openssl rand -hex 32)"
						echo -e "Done! Returning to menu..."
						sleep 2
						menu_reset
						full_menu
					else
						echo -e "${R}Your version is too low to be unenrolled without Br0ker, and it has been disabled.${N}\nReturning to menu..."
						sleep 3.2
					fi
				fi
			else
				if [[ "$MILESTONE" -ge 133 && "$MILESTONE" -le 142 ]]; then
					echo -e "\nYour version supports ${G}Quicksilver${N}!"
					echo ""
					echo -e "\n${R}Warning: This will prevent editing enrollment configs and enrolling until Quicksilver is removed.) [ONLY WORKS BELOW R143]\n${N}"
					echo -e "If you powerwash after updating past R142 you will be re-enrolled!"
					read -r -n 2 -s -p "Double click Y to continue, or hold any other key to exit..." confirmation
					if [[ "$confirmation" != "yy" ]]; then
						menu_reset
						full_menu
					fi
					echo -e "\nDisabling Enrollment..."
					sleep 1
					vpd -i RW_VPD -s "re_enrollment_key"="$(openssl rand -hex 32)"
					echo -e "Done! Returning to menu..."
					sleep 2
					menu_reset
					full_menu
				else
					if [[ "$MILESTONE" -ge 143 ]]; then
						echo -e "\n${R}Sorry, your version supports ${B}reqwrite${N}, but it has not released yet.${N}"
						sleep 0.67
						echo -e "Returning to menu..."
						sleep 3.5
					fi
				fi
			fi
		fi
	fi
	menu_reset
	full_menu
}

removeqs() {
	clear
	vpd -i RW_VPD -d "re_enrollment_key"
	echo -e "Removed Quicksilver! Returning to menu..."
	sleep 2.6
	menu_reset
	full_menu
}

helpmenu() {
	clear
	echo -e "
 ██████╗██████╗ ██████╗ ███╗   ██╗██████╗  ██████╗ ██╗     ██╗     
██╔════╝██╔══██╗╚════██╗████╗  ██║██╔══██╗██╔═══██╗██║     ██║     
██║     ██████╔╝ █████╔╝██╔██╗ ██║██████╔╝██║   ██║██║     ██║     
██║     ██╔══██╗ ╚═══██╗██║╚██╗██║██╔══██╗██║   ██║██║     ██║     
╚██████╗██║  ██║██████╔╝██║ ╚████║██║  ██║╚██████╔╝███████╗███████╗
 ╚═════╝╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝ [v$VERSION]   \n\n                 
██  ██ ██████ ██     █████▄ 
██████ ██▄▄   ██     ██▄▄█▀ 
██  ██ ██▄▄▄▄ ██████ ██     \n"
	echo -e "\n-- Q/A --\n\nQ: What are enrollment keys?\nA:Enrollment keys are a combination of your SDS (stable_device_secret) and SN (serial number) in your Chromebook's VPD.\n\nQ: What does the factory backup option do?\nA:The factory backup option backs up your 'Enrollment Keys' to a unique spot in RO_VPD."
	echo -e "\n\n-- What is Cr3nroll for? --"
	echo -e "\nCr3nroll is a general enrollment manager utility, it can handle unenrolling your Chromebook [with the most up-to-date unenrollments], and managing enrollment after you have disabled FWWP (${G}https://crosmium.dev/FWWP${N}),\nit can replace other older utilities such as Sh1mmer in 99% of cases, and it's actively maintained by its creator, DMD (or DMDCR on github)"
	echo -e "\n\nFun fact: Cr3nroll is based on Modmium's ${B}libmosh${N}, which is based on Cr3nroll. Weird, right?\n${D}(Libmosh is the library used by Modmium for its modified crosh TUI called 'MOSH')${N}"
	echo -e "\n\n${D}This menu is a work in progress${N}"
	echo -e "\n\n\n\n\n${B}-- Press enter to return to menu -- ${N}"
	stty echo
	read lol
	[[ $lol == $'\e[A\e[A\e[B\e[B\e[D\e[C\e[D\e[Cba' ]] && clear && echo -e "try stealing this, jackwagon!" && sleep 3 
	menu_reset
	full_menu
}

fixinput() {
	stty echo
	tput cnorm
}

touchdev() { # imported from sh1mmer
	clear
	menu_logo
	echo -e "Touching ${B}.developer_mode${N}..."
	local stateful_mnt=$(mktemp -d)
	mount "$stateful" "$stateful_mnt"
	touch "$stateful_mnt/.developer_mode"
	umount "$stateful_mnt"
	rmdir "$stateful_mnt"
	sync
	sleep 1
	menu_reset
	full_menu
}

unblockdev() {
	clear
	menu_logo
	echo -e "Unblocking devmode..."
	vpd -i RW_VPD -s "block_devmode=0"
	crossystem block_devmode=0
	sleep 1
	menu_reset
	full_menu
}

wipestate() { 
	clear
	menu_logo
	echo -e "Are you sure you want to wipe stateful?"
	read -r -p "(Y/N): " confirmation
	if [[ "$confirmation" == [Yy]* ]]; then
		mkfs.ext4 -F -b 4096 -L H-STATE "$stateful"
		echo -e "Stateful wiped successfully!\nReturning to menu..."
		sleep 1
		menu_reset
		full_menu
	else
		echo -e "Denied, returning to menu..."
		sleep 0.67
		menu_reset
		full_menu
	fi
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
    options=(
        "1) Save Current Enrollment Keys"
        "2) ${R}Load saved Enrollment Keys${N}"
        "3) Generate new Enrollment Keys"
        "4) ${R}Import Enrollment Info${N}"
        "5) Edit Enrollment list${N}"
        "6) ${B}Backup Enrollment Info${N}"
        "7) ${R}Restore Factory Enrollment Info${N}"
    )
    [[ "$factorysaved" == "1" ]] && options+=("8) ${G}Backup Factory Enrollment Info (Recommended)${N}")
	[[ -n "$(vpd -i RW_VPD -g "re_enrollment_key" 2>/dev/null)" ]] && quicksilver=1
    [[ "$PAYLOAD_MODE" != "true" ]] && [[ $quicksilver != 1 ]] && options+=("D) Deprovision/Unenroll")
	[[ $quicksilver == 1 ]] && options+=("R) Remove Quicksilver")
    [[ "$INSIDE_SHIM" == "true" ]]   && options+=("T) Touch .developer_mode" "W) ${Y}WIPE STATEFUL${N}" "U) Unblock devmode" "B) Bash")
    options+=("H) Help" "0) Exit")
    num_options=${#options[@]}
}


milestone
menu_reset

selector() {
    local input="${1:-${options[$selected_index]}}"
    local clean_input=$(echo "$input" | sed 's/\x1b\[[0-9;]*m//g')

    case "$clean_input" in
        1*)
			fixinput
			savecurrentkeys ;;
        2*)
			fixinput
			loadsavedkeys ;;
        3*)
			fixinput
			genkeys ;;
		4*)
			fixinput
			importkeys ;;
		5*)
			fixinput
			editkeys ;;
		6*)
			fixinput
			backupvpd ;;
		7*)
			fixinput
			restorefactoryinfo ;;
		8*)
			fixinput
			firstfactorybackup ;;
		[Hh]*)
			fixinput
			helpmenu ;;
        [Bb]*)
			runscript "/bin/bash" ;;
        [Dd]*)
			fixinput
			deprovision ;;
        [Rr]*)
			fixinput
			removeqs ;;
		[Tt]*)
			fixinput
			touchdev ;;
		[Ww]*)
			fixinput
			wipestate ;;
		[Uu]*)
			fixinput
			unblockdev ;;
        0*)
            fixinput
			if [[ "$INSIDE_SHIM" == "true" ]]; then
				echo -e "Exiting..."
				reboot
			else
				exit 0
			fi
			;;
        *)
            return ;;
    esac
}
clear
full_menu
tput cnorm
selector
