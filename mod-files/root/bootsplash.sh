#!/bin/bash

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

img_path="$(pwd)/.modmium_bootsplash.png"
cros_assets="/usr/share/chromeos-assets/images_100_percent"

# lol I dont really know how to do loops for stuff like this in bash, like where its like 00,01,02,03,etc
# idc brooo ill just hardcode it
# someone whos actually good with bash (mariah :pray:) make this tuff and not skidded

# lol nvm im gonna steal from murkmod https://github.com/rainestorme/murkmod/blob/main/image_patcher.sh#L237
for i in $(seq -f "%02g" 0 30); do
    # echo "${Y}removing frame ${i}" # debugging
    rm "$cros_assets/boot_splash_frame${i}.png"
done

# echo "copying bootsplash from $img_path" # debugging
cp "$img_path" "$cros_assets/boot_splash_frame00.png"
echo -e "${G}done.${N}"