#!/bin/bash

# this is a modified version of MOSH 

# -- FLAGS --
menu_text="Modmium pre-install script!"
# -----------------------

# TUI colors :D
B='\033[1;36m'
G='\033[1;32m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'
D='\033[1;90m'

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

# this part below is very WIP and taken from cr3nroll's shim branch
flashdevfw() {
        echo -e "This feature is not finished!"
        sleep 999999999 # temporary
        # read firmware
        DEVFW=$(vpd -i RO_VPD -g "dev_firmware")
        if [[ $DEVFW != 1 ]]; then
						# flash gbb flags, devkeys, and set dev_firmware to 1 to prevent accidental reflashing :3
            /usr/share/vboot/bin/set_gbb_flags.sh 0x80b1
            /usr/share/vboot/bin/make_dev_firmware.sh --nomod_gbb_flags --nomod_hwid --backup_dir $BACKUPDIR
            vpd -i RO_VPD -s "dev_firmware"=1
        else 
        		echo -e "You are already using DevFW (Devkeys)!"
        fi
}
main() { 
    logo
    sleep 0.1
    echo ""
    echo -e "This is Modmium's pre-install script!"
    echo -e "This requires write protection to be disabled, and it will be checked before this script attempts anything (CAN BE OVERRIDEN FOR THOSE WITH KEYROLL PREVENTION)"
    echo ""
    echo -e "This script is a huge WIP, let dmd cook ;D"
    sleep 1
}

clear
main
