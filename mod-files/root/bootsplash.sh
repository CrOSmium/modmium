#!/bin/bash

# written by xz8f

# colors :pray:
B='\033[1;36m' 
G='\033[1;32m' 
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'    
D='\033[1;90m'
P='\033[1;35m'

echo -e "${P}+##############################################+"
echo -e "| Bootsplash replacer                          |"
echo -e "| -------------------------------------------- |"
echo -e "| Replaces the stock chromeos bootsplash       |"
echo -e "+##############################################+${N}"

# uhhh ill add custom images later lol

replace() {
    img_path="$(pwd)/.modmium_bootsplash.png"
    cros_assets="/usr/share/chromeos-assets/images_100_percent"
    backup_dir="$(pwd)/.stock_bootsplash"
    if [ -d "$backup_dir" ]; then
        echo ":3" >/dev/null 2>&1 # whats the bash equivalent for like "pass" in python
    else
        echo -e "${G}creating backup directory${N}"
        mkdir -p "$backup_dir"
    fi
    # lol I dont really know how to do loops for stuff like this in bash, like where its like 00,01,02,03,etc
    # idc brooo ill just hardcode it
    # someone whos actually good with bash (mariah :pray:) make this tuff and not skidded
    # lol nvm im gonna steal from murkmod https://github.com/rainestorme/murkmod/blob/main/image_patcher.sh#L237
    echo -e "${Y}backing up current bootsplash${N}"
    for i in $(seq -f "%02g" 0 30); do
        # echo "${Y}removing frame ${i}" # debugging
        mv "$cros_assets/boot_splash_frame${i}.png" "$backup_dir/boot_splash_frame${i}.png" >/dev/null 2>&1 # maybe I should just make a dedicated backup function
    done
    echo -e "${G}replacing bootsplash${N}"
    # echo "copying bootsplash from $img_path" # debugging
    cp "$img_path" "$cros_assets/boot_splash_frame00.png" >/dev/null 2>&1
    echo -e "${G}done.${N}"
}

restore() {
    img_path="$(pwd)/.modmium_bootsplash.png"
    cros_assets="/usr/share/chromeos-assets/images_100_percent"
    backup_dir="$(pwd)/.stock_bootsplash"
    if [ -d "$backup_dir" ]; then
        echo ":3" >/dev/null 2>&1
    else
        echo -e "${R}backup directory does not exist${N}"
        exit 1
    fi
    echo -e "${Y}restoring bootsplash${N}"
    for i in $(seq -f "%02g" 0 30); do
        # echo "${Y}removing frame ${i}" # debugging
        mv "$backup_dir/boot_splash_frame${i}.png" "$cros_assets/boot_splash_frame${i}.png" >/dev/null 2>&1
    done
    echo -e "${G}done.${N}"
}

echo "${G}"
echo "1. Replace bootsplash"
echo "2. Restore normal bootsplash"
echo "${N}"

read -p "choose an option: " choice

if [ "$choice" = "1" ]; then
    replace
elif [ "$choice" = "2" ]; then
    restore
else
    echo -e "invalid option, select either 1 (restore) or 2 (replace)"
fi
