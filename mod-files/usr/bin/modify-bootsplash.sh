#!/bin/bash
# originally written by xz8f
# rewritten by mariah carey for MOSH

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
	for splashframe in $(find /usr/share/chromeos-assets/images_100/percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp /root/.modmium_bootsplash.png $splashframe
		fi
	done
	echo -e "${G}Replaced bootsplash!${N}"
}

replace_custom() {
	echo -e "${G}enter the FULL path to the custom image!${N}"
	read -rep " > " custom_img_path
	if [ -f "$custom_img_path" ]; then
		for splashframe in $(find /usr/share/chromeos-assets/images_100/percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp "$custom_img_path" $splashframe
		fi
	done
	echo -e "${G}Replaced bootsplash!${N}"
	else
    	echo -e "${R}The image $custom_img_path does not exist! make sure you have the path right${N}"
	fi
}

restore() {
	for splashframe in $(find /usr/share/chromeos-assets/images_100_percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv "$splashframe".old "$splashframe"
	done
	echo -e "${G}Restored bootsplash!${N}"
}

download_backup() {
	# I am hosting the stock bootsplash images on https://dl.xz8f.gay/chromeos_bootsplash.zip
	# just need to download, unzip, copy files
	echo "not implemented yet"
}

echo -e "${G}1. Replace bootsplash with modmium bootsplash${N}"
echo -e "${G}2. Replace bootsplash with custom image${N}"
echo -e "${G}3. Restore normal bootsplash{$N}"
# echo -e "${G}4. Download stock bootsplash and save to backup${N}"


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
	echo -e "Invalid option, select either 1 (replace), 2 (replace with custom image) or 3 (restore)" # or 4 (download)
fi
sleep 2
return
