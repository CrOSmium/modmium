#!/bin/bash
# originally written by xz8f (and currently maintained by her)
# partially rewritten by mariah carey for MOSH

# colors :pray:
B='\033[1;36m' 
G='\033[1;32m' 
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'    
D='\033[1;90m'
P='\033[1;35m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline

echo -e "${P}+##############################################+"
echo -e "| Bootsplash replacer                          |"
echo -e "| -------------------------------------------- |"
echo -e "| Replaces the stock chromeos bootsplash       |"
echo -e "+##############################################+${N}"
echo ""

replace() {
	for splashframe in $(find /usr/share/chromeos-assets/images_100_percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp /root/.modmium_bootsplash.png $splashframe
		fi
	done
	echo -e "${G}replaced bootsplash!${N}"
}

replace_custom() {
	echo -e "${G}enter the FULL path to the custom image!${N}"
	read -rep " > " custom_img_path
	if [ -f "$custom_img_path" ]; then
		for splashframe in $(find /usr/share/chromeos-assets/images_100_percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp "$custom_img_path" $splashframe
		fi
	done
	echo -e "${G}replaced bootsplash!${N}"
	else
    	echo -e "${R}the image $custom_img_path does not exist! make sure you have the path right${N}"
	fi
}

restore() {
	for splashframe in $(find /usr/share/chromeos-assets/images_100_percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv "$splashframe".old "$splashframe"
	done
	echo -e "${G}restored bootsplash!${N}"
	echo -e "${Y}note: if the bootsplash is missing or it didn't restore, use the \"download stock bootsplash\" option" # lol just incase something happens ig
}

download_backup() {
	cros_assets="/usr/share/chromeos-assets/images_100_percent"
	echo -e "${G}downloading stock bootsplash${N}"
	curl -LO https://dl.xz8f.gay/chromeos_bootsplash.zip
	echo -e "${Y}unzipping${N}"
	bsdtar -xf chromeos_bootsplash.zip
	echo -e "${Y}creating new backup${N}" # should this say something different? idk
	for i in $(seq -f "%02g" 0 30); do
    	mv "boot_splash_frame${i}.png" "$cros_assets/boot_splash_frame${i}.old" # I could probably do something like mv "boot_splash_frame*.png" but I dont wanna bother with that rn
	done
	echo -e "${Y}cleaning up${N}"
	rm chromeos_bootsplash.zip
	echo -e "${G}done! use option 3 (Restore stock bootsplash) to restore the stock bootsplash${N}"
}

echo -e "${G}1. Replace bootsplash with modmium bootsplash${N}"
echo -e "${G}2. Replace bootsplash with custom image${N}"
echo -e "${G}3. Restore stock bootsplash${N}"
echo -e "${G}4. Download stock bootsplash and save to backup${N}"


read -rep "Choose an option: " choice

if [ "$choice" == "1" ]; then
	replace
elif [ "$choice" == "2" ]; then
	replace_custom
elif [ "$choice" == "3" ]; then
	restore
elif [ "$choice" == "4" ]; then
	download_backup
else
	echo -e "Invalid option, select either 1 (replace), 2 (replace with custom image) or 3 (restore) or 4 (download stock)"
fi
read -p "press enter to go back to the menu" temp
return
