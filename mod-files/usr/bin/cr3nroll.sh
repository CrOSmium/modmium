#!/bin/bash

# SCRIPT VERSION: v1.1.2

# -- CUSTOM FLAGS --
BROKER_PATH="broker.sh" # if you put broker in another spot, put the path here :3
BROKER_ENABLED="false"  # enable or disable launching br0ker for supported versions
INSIDE_SHIM="false" # set to 'true' if you want bash as an option and reboot on exit
PAYLOAD_MODE="true" # set to 'true' if you do not want deprovision/unenroll as an option, this only works if INSIDE_SHIM="false"

# -- { DO NOT MODIFY } --
selected_index=0
writeprotect=$(flashrom --wp-status | grep disabled)
factoryserial=$(vpd -i RO_VPD -g "factory_serial_number")
# MILESTONE=$(cat /etc/lsb-release | grep MILESTONE | sed 's/^.*=//' ) # this was removed because it was getting the shims version lmao
if [[ "$factoryserial" == "" ]]; then
    factorysaved="1"
fi
# -----------------------

# -- TESTING FLAGS :3 --
# FLAG_MILESTONE=143
# BROKER_ENABLED="false"
# writeprotect=enabled

# -- MAIN SCRIPT --
tput civis # :whale:

# colors that i totally didn't steal from a previous project
B='\033[1;36m'
G='\033[1;32m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'
D='\033[1;90m'

menu_reset() {
    if [[ "$factorysaved" == "1" ]]; then
        if [[ "$INSIDE_SHIM" == "true" ]]; then
            options=("Save Current Enrollment Keys" "${R}Load saved Enrollment Keys${N}" "Generate new Enrollment Keys" "${R}Import Enrollment Info${N}" "Edit Enrollment list${N}" "${B}Backup Enrollment Info${N}" "${R}Restore Factory Enrollment Info${N}" "${G}Backup Factory Enrollment Info (Recommended)${N}" "Deprovision/Unenroll" "Bash" "Exit")
        else
            options=("Save Current Enrollment Keys" "${R}Load saved Enrollment Keys${N}" "Generate new Enrollment Keys" "${R}Import Enrollment Info${N}" "Edit Enrollment list${N}" "${B}Backup Enrollment Info${N}" "${R}Restore Factory Enrollment Info${N}" "${G}Backup Factory Enrollment Info (Recommended)${N}" "Deprovision/Unenroll" "Exit")
        fi
    else
        if [[ "$INSIDE_SHIM" == "true" ]]; then
            options=("Save Current Enrollment Keys" "${R}Load saved Enrollment Keys${N}" "Generate new Enrollment Keys" "${R}Import Enrollment Info${N}" "Edit Enrollment list${N}" "${B}Backup Enrollment Info${N}" "${R}Restore Factory Enrollment Info${N}" "Deprovision/Unenroll" "Bash" "Exit")
        else
            if [[ "$PAYLOAD_MODE" == "true" ]]; then
                options=("Save Current Enrollment Keys" "${R}Load saved Enrollment Keys${N}" "Generate new Enrollment Keys" "${R}Import Enrollment Info${N}" "Edit Enrollment list${N}" "${B}Backup Enrollment Info${N}" "${R}Restore Factory Enrollment Info${N}" "Exit")
            else
                options=("Save Current Enrollment Keys" "${R}Load saved Enrollment Keys${N}" "Generate new Enrollment Keys" "${R}Import Enrollment Info${N}" "Edit Enrollment list${N}" "${B}Backup Enrollment Info${N}" "${R}Restore Factory Enrollment Info${N}" "Deprovision/Unenroll" "Exit")
            fi
        fi    
    fi
    if [[ "$(vpd -i RW_VPD -g "re_enrollment_key")" != "" ]]; then
        options=("Remove Quicksilver${N}" "Exit")
        selected_index=0
    fi
    num_options=${#options[@]}
}

menu_reset

# stolen sh1mmer code

run_task() {
    if "$@"; then
        echo "Done."
    else
        echo "TASK FAILED."
    fi
    echo "Press enter to return to the main menu."
    read -res
    menu_reset
    full_menu
}

# br0ker milestone getter
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
CROS_DEV=$(get_largest_cros_blockdev)
MNT=$(mktemp -d)
for i in 3 5; do
    mount -o ro "$(format_part_number "$CROS_DEV" "$i")" "$MNT" >/dev/null 2>&1 || continue
    # end of stolen code!
    NEW_MILESTONE=$(cat "$MNT/etc/lsb-release" | grep "CHROMEOS_RELEASE_CHROME_MILESTONE" | sed 's/^.*=//')
    if [ ! -z "$NEW_MILESTONE" ]; then
        MILESTONE=$NEW_MILESTONE
    fi
    umount "$MNT"
done
if [[ "$FLAG_MILESTONE" != "" ]]; then
    MILESTONE=$FLAG_MILESTONE
fi
selector() {
    clear
    if [[ "${options[$selected_index]}" == "Edit Enrollment list${N}" ]]; then
        clear
        menu_logo
        echo -e "Getting keys..."
        sleep 2
        mapfile -t KEYNAMES < <(vpd -i RW_VPD -l | grep '"saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
        #   mapfile -t KEYNAMES < <(echo -e "saved_test" "saved_test_serial" | grep '^saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
        clear
        menu_logo
        echo -e "\n\nCurrently active serial number: '$(vpd -i RO_VPD -g "serial_number")'"
        echo -e "Select a key to ${R}DELETE${N} from the saved enrollment keys."
        echo ""
        sleep 1
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
                    echo -e "\n${R}Warning: This will ${R}erase${N} the selected keys from the saved enrollment keys PERMANENTLY!!${N}\n"
                    read -r -n 2 -s -p "Double click Y to continue, or hold any other key to exit..." confirmation
                    if [[ "$confirmation" != "yy" ]]; then
                        menu_reset
                        full_menu
                    fi
                    clear
                    menu_logo
                    sleep 3.4
                    overrideSet2() {
                        clear
                        trap 'echo -e "\nErase cancelled, no keys were deleted!" && sleep 2 && menu_reset && full_menu ' SIGINT
                        echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        sleep 1.5
                        clear
                        echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "Erasing in: 3"
                        sleep 1.5
                        clear
                        echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "Erasing in: 2"
                        sleep 1.5
                        clear
                        echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "Erasing in: 1"
                        sleep 2
                        clear

                        echo -e "Erasing selected keys from RW_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "${R}Writing keys...${N}"
                        sleep 0.8
                        clear
                        menu_logo
                        echo -e "Erasing selected keys from RW_VPD..."
                        sleep 1.7
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
    fi
    if [[ "${options[$selected_index]}" == "${R}Import Enrollment Info${N}" ]]; then
        clear
        menu_logo
        echo -e "Import Enrollment Info (from a file)"
        echo -e "${R}THIS WILL OVERWRITE YOUR ENTIRE VPD WITH THE CONTENTS OF THE FILES YOU PROVIDE!!${N}"
        echo ""
        echo -e "\n\nEnter directory to import from (must contain RO.vpd and RW.vpd):"
        local validDir=false
				while [[ $validDir == "false" ]]; do
					echo -ne "Directory: "
        	read impdirec
        	if [[ -d "$impdirec" ]]; then
						if [[ -f "$impdirec/RO.vpd" ]] && [[ -f "$impdirec/RW.vpd" ]]; then
							echo "Importing from: $impdirec"
							echo -ne "Is this correct? [Y/n]"
							read -n1
							if [[ $REPLY =~ ^[Yy]$ ]]; then
								validDir=true
							else
								echo "Reprompting..."
							fi
						else
							echo -e "${R}Invalid directory (no export found)${N}"
						fi
					else
						echo -e "${R}Invalid directory (does not exist)${N}"
					fi
				done
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
    fi
    if [[ "${options[$selected_index]}" == "${R}Restore Factory Enrollment Info${N}" ]]; then
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
            sleep 1.2
            menu_reset
            full_menu
        fi
        echo -e "Restoring factory enrollment keys..."
        sleep 1
        vpd -i RO_VPD -s "stable_device_secret_DO_NOT_SHARE"="$(vpd -i RO_VPD -g "factory_stable_device_secret")"
        sleep 0.4
        vpd -i RO_VPD -s "serial_number"="$(vpd -i RO_VPD -g "factory_serial_number")"
        sleep 0.4
        echo -e "Restored enrollment keys successfully! Returning to menu..."
        menu_reset
        full_menu
    fi
    if [[ "${options[$selected_index]}" == "Exit" ]]; then
        if [[ "$INSIDE_SHIM" == "true" ]]; then
            echo "Exiting & Rebooting"
            sleep 0.5
            clear
            tput cnorm
            reboot
            exit 0
        else
            echo "Exiting."
            sleep 0.5
            clear
            tput cnorm
            exit 0
        fi
    fi
    if [[ "${options[$selected_index]}" == "Save Current Enrollment Keys" ]]; then
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
        sleep 0.4
        sleep 0.4
        echo -e "Reading VPD..."
        sleep 0.67
        STABLEDEV=$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")
        echo -e "Read stable_device_secret!"
        sleep 0.4
        SERIAL=$(vpd -i RO_VPD -g "serial_number")
        echo -e "Read serial_number!"
        sleep 1.2
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
        full_menu
    fi
    if [[ "${options[$selected_index]}" == "Remove Quicksilver${N}" ]]; then
        vpd -i RW_VPD -d "re_enrollment_key"
        echo -e "Removed Quicksilver! Returning to menu..."
        sleep 2.6
        menu_reset
        full_menu
    fi
    if [[ "${options[$selected_index]}" == "Deprovision/Unenroll" ]]; then
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
    fi
    if [[ "${options[$selected_index]}" == "${B}Backup Enrollment Info${N}" ]]; then
        menu_logo
        echo -e "Backup Enrollment Info"
        echo ""
        echo -e "Where would you like to backup your VPD to? (makes a new directory '/vpd/' underneath the selected one)"
        local validDir=false
				while [[ $validDir == "false" ]]; do
					echo -ne "Directory: "
					read sdirec
        	sleep 0.67
        	if [[ -d "$sdirec" ]]; then
						echo "Importing from: $sdirec"
						echo -ne "Is this correct? [Y/n]"
						read -n1
						if [[ $REPLY =~ ^[Yy]$ ]]; then
							validDir=true
						else
							echo "Reprompting..."
						fi
					else
						echo -e "${R}Invalid directory (does not exist)${N}"
					fi
				done
            vpd -i RO_VPD -l
            sleep 0.67
            vpd -i RW_VPD -l
            sleep 0.67
            mkdir $sdirec/vpd
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
                sleep 4
                echo -e "Returning to menu..."
                sleep 1.2
                menu_reset
                full_menu
						fi	
        fi
    if [[ "${options[$selected_index]}" == "${G}Backup Factory Enrollment Info (Recommended)${N}" ]]; then
        menu_logo
        echo -e "Backup Factory Enrollment Info"
        echo ""
        echo -e "${R}This is irreversible!!${N}\n\n${G}This will save these two keys: 'factory_serial_number' as '$(vpd -i RO_VPD -g "serial_number")' and 'factory_stable_device_secret' as '$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")'${N}"

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
            fi
            sleep 0.67
            if [[ "$(vpd -i RO_VPD -g "factory_stable_device_secret")" == "" ]]; then
                if [[ "$wrotekey" == "1" ]]; then
                    vpd -i RO_VPD -s "factory_stable_device_secret"="$(vpd -i RO_VPD -g "stable_device_secret_DO_NOT_SHARE")"
                    echo -e "${G}Written!${N}"
                    wrotekey=$(($wrotekey + 1))
                else
                    echo -e "Backup incomplete! Please contact support in the discord, or fix it yourself by running these commands when your factory info is CONFIRMED active."
                    echo -e "vpd -i RO_VPD -d "factory_stable_device_secret""
                    echo -e "vpd -i RO_VPD -d "factory_serial_number""
                    echo -e "vpd -i RW_VPD -d "factory_backup""
                    echo -e "Running these WILL wipe your currently backed up factory info!"
                fi
            else
                echo -e "Key (factory_stable_device_secret) already saved, no need to write!"
            fi
            sleep 0.67
            vpd -i RW_VPD -s "factory_backup"="2"
            echo -e "Enrollment info backed up under 'factory_serial_number' and 'factory_stable_device_secret'!\nReturning to menu..."
            sleep 4
            menu_reset
            full_menu
        else
            menu_reset
            full_menu
        fi
    fi


    # SHIM UNIQUE OPTION!!
    if [[ "${options[$selected_index]}" == "Bash" ]]; then
        clear
        menu_logo
        tput cnorm
        run_task bash
    fi

    
    if [[ "${options[$selected_index]}" == "Generate new Enrollment Keys" ]]; then
        menu_logo
        echo -e "Would you like to generate and save new Enrollment Keys? (Does not override currently selected keys)"
        tput cnorm
        echo -ne "(Y/N): "
        read YESNT2
        if [[ "${YESNT2}" = [Yy] ]]; then
            sleep 0.67
            echo -e "Generating new Keys..."
            sleep 0.4

            gensdev=$(openssl rand -hex 32)
            echo -e "Generated stable_device_secret: '$gensdev'"
            sleep 0.4
            echo -e "Would you like to have your serial number auto-generated, or make one yourself? (A/M) [A = Auto, M = Manual]"
            read -r -n 1 -p "(Press A or M to continue)" snauto
            if [[ "${snauto}" == [Aa] ]]; then
                echo -e "\nGenerating serial number..."
                sleep 0.67
                # super mega cool serial number generator that i made myself
                # (google pls dont sue me i made this based on structure ive seen in SOME serial numbers)
                KEYNAME="$(
                    LC_ALL=C printf '%s' \
                        "$(openssl rand -base64 8 | tr -dc 'A-Z' | head -c2)" \
                        "$(openssl rand -base64 8 | tr -dc '0-9' | head -c1)" \
                        "$(openssl rand -base64 8 | tr -dc 'A-Z' | head -c3)" \
                        "$(openssl rand -base64 8 | tr -dc 'A-Z0-9' | head -c3)"
                )"
            else
                echo -e "What do you want your serial number to be?"
                currentsn=$(vpd -i RO_VPD -g "serial_number")
                echo -e "Your currently set one is: '$currentsn'"
                echo -e "Warning: Setting your serial number or Keyname blank WILL corrupt your enrollment keys!!"
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
                    sleep 0.4
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
                sleep 0.67
                vpd -i RW_VPD -s "saved_"$SKNAME"_stable_device_secret"="$gensdev"
                sleep 0.4
                vpd -i RW_VPD -s "saved_"$SKNAME"_serial_number"="$KEYNAME"
                sleep 1
                echo -e "Finished!"
                sleep 3
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
    fi
    if [[ "${options[$selected_index]}" == "${R}Load saved Enrollment Keys${N}" ]]; then
        clear
        menu_logo
        echo -e "Getting keys..."
        sleep 2
        mapfile -t KEYNAMES < <(vpd -i RW_VPD -l | grep '"saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
        #   mapfile -t KEYNAMES < <(echo -e "saved_test" "saved_test_serial" | grep '^saved_' | awk -F'[ =]' '{print $1}' | awk -F_ '{print $2}' | sort -u)
        clear
        echo -e " █████                              █████                                               █████                                              
░░███                              ░░███                                               ░░███                                               
 ░███         ██████   ██████    ███████      █████   ██████   █████ █████  ██████   ███████                                               
 ░███        ███░░███ ░░░░░███  ███░░███     ███░░   ░░░░░███ ░░███ ░░███  ███░░███ ███░░███                                               
 ░███       ░███ ░███  ███████ ░███ ░███    ░░█████   ███████  ░███  ░███ ░███████ ░███ ░███                                               
 ░███      █░███ ░███ ███░░███ ░███ ░███     ░░░░███ ███░░███  ░░███ ███  ░███░░░  ░███ ░███                                               
 ███████████░░██████ ░░████████░░████████    ██████ ░░████████  ░░█████   ░░██████ ░░████████                                              
░░░░░░░░░░░  ░░░░░░   ░░░░░░░░  ░░░░░░░░    ░░░░░░   ░░░░░░░░    ░░░░░     ░░░░░░   ░░░░░░░░                                               
                                                                                                                                           
                                                                                                                                           
                                                                                                                                           
                                        ████  ████                                       █████       █████                                 
                                       ░░███ ░░███                                      ░░███       ░░███                                  
  ██████  ████████   ████████   ██████  ░███  ░███  █████████████    ██████  ████████   ███████      ░███ █████  ██████  █████ ████  █████ 
 ███░░███░░███░░███ ░░███░░███ ███░░███ ░███  ░███ ░░███░░███░░███  ███░░███░░███░░███ ░░░███░       ░███░░███  ███░░███░░███ ░███  ███░░  
░███████  ░███ ░███  ░███ ░░░ ░███ ░███ ░███  ░███  ░███ ░███ ░███ ░███████  ░███ ░███   ░███        ░██████░  ░███████  ░███ ░███ ░░█████ 
░███░░░   ░███ ░███  ░███     ░███ ░███ ░███  ░███  ░███ ░███ ░███ ░███░░░   ░███ ░███   ░███ ███    ░███░░███ ░███░░░   ░███ ░███  ░░░░███
░░██████  ████ █████ █████    ░░██████  █████ █████ █████░███ █████░░██████  ████ █████  ░░█████     ████ █████░░██████  ░░███████  ██████ 
 ░░░░░░  ░░░░ ░░░░░ ░░░░░      ░░░░░░  ░░░░░ ░░░░░ ░░░░░ ░░░ ░░░░░  ░░░░░░  ░░░░ ░░░░░    ░░░░░     ░░░░ ░░░░░  ░░░░░░    ░░░░░███ ░░░░░░  
                                                                                                                          ███ ░███         
                                                                                                                         ░░██████          
                                                                                                                          ░░░░░░           "
        echo -e "| Cr3nroll By OSmium (CrOSmium on Github) |"
        echo ""
        echo ""
        echo -e "\nCurrently active serial number: '$(vpd -i RO_VPD -g "serial_number")'"
        echo ""

        sleep 1
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
                    sleep 3.4
                    overrideSet() {
                        clear
                        trap 'echo -e "\nWrite cancelled, no keys were written!" && sleep 2 && menu_reset && full_menu ' SIGINT
                        echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        sleep 1.5
                        clear
                        echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "Writing in: 3"
                        sleep 1.5
                        clear
                        echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "Writing in: 2"
                        sleep 1.5
                        clear
                        echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
                        echo -e "Writing in: 1"
                        sleep 2
                        clear

                        echo -e "Writing selected keys to RO_VPD in 3 seconds, press CTRL-C to cancel if you change your mind. ${R}THIS IS HIGHLY DESTRUCTIVE!!${N}"
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
                        sleep 2
                        echo -e "Writing keys to RO_VPD..."
                        vpd -i RO_VPD -s "serial_number"="$(vpd -i RW_VPD -g "saved_${key}_serial_number")"
                        vpd -i RO_VPD -s "stable_device_secret_DO_NOT_SHARE"="$(vpd -i RW_VPD -g "saved_${key}_stable_device_secret")"
                        echo -e "Keys written to VPD!"
                        sleep 4
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
                selected_index=$(((selected_index - 1 + num_options) % num_options))
                ;;
            '[B')
                selected_index=$(((selected_index + 1) % num_options))
                ;;
            esac
        elif [[ "$key" == "" ]]; then
            break
        fi
        tput rc
    done
    selector
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
    echo -e "| By OSmium (CrOSmium on Github) |"
    echo ""
}
display_menu() {
    tput sc
    menu_logo

    if [[ "$writeprotect" == *"disabled"* ]]; then
        echo -e "You currently have Firmware Write Protection set to ${R}(DISABLED)${N}, all features *should* work properly. Have fun :D"
    else
        echo -e "You currently have Firmware Write Protection set to ${G}(ENABLED)${N}, you will be ${R}unable${N} to modify your current enrollment info until you disable it [${G}https://crosmium.dev/FWWP${N}]!"
    fi
    if [[ "$MILESTONE" == "" ]]; then
        echo -e "${R}Could not get ChromeOS version milestone, is ChromeOS installed?${N}"
    else
        if [[ "$MILESTONE" -ge 143 ]]; then
            echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N}, therefore your version ${R}does not have an available unenrollment${N}. Try downgrading if possible!"
        else
            echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} --"
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
