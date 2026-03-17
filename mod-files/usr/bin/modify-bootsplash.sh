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
fail() {
	echo -e "$1"
	sleep 3
	return
}
cros_assets="/usr/share/chromeos-assets/images_100_percent"
cros_assets_2="/usr/share/chromeos-assets/images_200_percent"

echo -e "${P}+##############################################+"
echo -e "| Bootsplash Replacer                          |"
echo -e "| -------------------------------------------- |"
echo -e "| Replaces the stock ChromeOS bootsplash       |"
echo -e "+##############################################+${N}"
echo ""

replace() {
	for splashframe in $(find $cros_assets -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp /root/.modmium_bootsplash.png $splashframe
		fi
	done
	for splashframe in $(find $cros_assets_2 -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp /root/.modmium_bootsplash.png $splashframe
		fi
	done
	
	echo -e "${B}Replaced bootsplash!${N}"
}

replace_custom() { # this is broken rn, can someone figure out whats happening? it seems like it just doesnt replace it at all
	echo -e "${G}Enter the FULL path to the custom image!${N}"
	read -rep " > " custom_img_path
	if [ -f "$custom_img_path" ]; then
		for splashframe in $(find $cros_assets -mindepth 1 -name 'boot_splash_frame*.png'); do
			mv $splashframe "$splashframe".old
			if [[ $splashframe == *"00.png" ]]; then
				cp "$custom_img_path" $splashframe
			fi
		done
		for splashframe in $(find $cros_assets_2 -mindepth 1 -name 'boot_splash_frame*.png'); do
			mv $splashframe "$splashframe".old
			if [[ $splashframe == *"00.png" ]]; then
				cp "$custom_img_path" $splashframe
			fi
		done
		echo -e "${B}Replaced bootsplash!${N}"
	else
    	fail "${R}The image $custom_img_path does not exist! Make sure you have the path right!${N}"
	fi
}

restore() {
	for splashframe in $(find $cros_assets -mindepth 1 -name 'boot_splash_frame*.old'); do
		mv "$splashframe" "${splashframe%.*}"
	done
	for splashframe in $(find $cros_assets_2 -mindepth 1 -name 'boot_splash_frame*.old'); do
		mv "$splashframe" "${splashframe%.*}"
	done
	
	echo -e "${B}Restored bootsplash!${N}"
	echo -e "${Y}Note: if the bootsplash is missing or it didn't restore, use the \"Download stock bootsplash\" option${N}" # lol just incase something happens ig
}

download_backup() {
	echo -e "${G}Downloading stock bootsplash...${N}"
	curl -LO https://dl.xz8f.gay/chromeos_bootsplash.zip
	echo -e "${Y}Unzipping...${N}"
	bsdtar -xf chromeos_bootsplash.zip
	echo -e "${Y}Creating backup...${N}" # should this say something different? idk
	for splashframe in boot_splash_frame*.png; do
    	mv $splashframe $cros_assets/$splashframe.old # I could probably do something like mv "boot_splash_frame*.png" but I dont wanna bother with that rn
	done
	for splashframe in boot_splash_frame*.png; do
    	mv $splashframe $cros_assets_2/$splashframe.old # I could probably do something like mv "boot_splash_frame*.png" but I dont wanna bother with that rn
	done
	echo -e "${Y}Cleaning up!${N}"
	rm chromeos_bootsplash.zip
	echo -e "${B}Done! Use option 3 (Restore stock bootsplash) to restore the stock bootsplash${N}"
}

remove() {
	echo -e "${Y}This will remove the bootsplash ENTIRELY. use restore to fix it.${N}"
	read -p "Contnue? (y/N) " -n 1 -r
	echo   
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo -e "${Y}Removing bootsplash...${N}"
		rm "$cros_assets/boot_splash_frame*.png"
		rm "$cros_assets_2/boot_splash_frame*.png"
		echo -e "${G}Removed bootsplash!${N}"
	fi
}

echo -e "${G}1. Replace bootsplash with modmium bootsplash (the one used during building)${N}"
echo -e "${G}2. Replace bootsplash with custom image${N}"
echo -e "${G}3. Restore stock bootsplash${N}"
echo -e "${G}4. Download stock bootsplash and save to backup${N}"
echo -e "${G}5. Remove bootsplash${N}"


read -rep "Choose an option: " choice
case $choice in
	"1")
		replace
		;;
	"2")
		replace_custom
		;;
	"3")
		restore
		;;
	"4")
		download_backup
		;;
	"5")
		remove
		;;
	*)
		echo -e "Invalid option, select either 1 (replace), 2 (replace with custom image), 3 (restore), 4 (download stock), or 5 (remove)"
		;;
esac

fail "Returning..." # not truly a "fail" but it's less clunky and more consistent with how other scripts go back to menu
