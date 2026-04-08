#!/bin/bash
# originally written by xz8f (and currently maintained by her)
# partially rewritten by mariah carey for MOSH

# colors :pray:
B='\033[38;5;45m'
G='\033[38;5;46m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
P='\033[38;5;135m'
N='\033[0m'
D='\033[1;90m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline

fail() {
	echo -e "$1"
	for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0); do
		# rm -rf ${downloadsDir}/bootsplashes
		sudo chown -R chronos:chronos "$downloadsDir/bootsplashes"
	done # we do this because you can't delete them in the files app for some reason? idk man
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
echo -e "${D}(Hit Ctrl+C to return to MOSH)${N}"

# gets chosen bootsplash
get_installed_bootsplashes() {
	for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0); do
		mkdir -p ${downloadsDir}/bootsplashes
		cp /bootsplash/* ${downloadsDir}/bootsplashes >/dev/null 2>&1
		chmod 777 ${downloadsDir}/bootsplashes/*
		chown 0:0 ${downloadsDir}/bootsplashes/*
	done
	echo -e "${G}Placed all installed bootsplashes in Downloads/bootsplashes/ for you to preview.${N}
Open the Files app to see them."
	for image in $(find /bootsplash -mindepth 1 -name '*.png' | sort); do
		echo $(basename $image)
	done
	echo -ne "Enter one of the filenames above: "
	read -rep "" bootsplash
	bootsplash=/bootsplash/$bootsplash
	shouldExit=true
	for image in $(find /bootsplash -mindepth 1 -name '*.png' | sort); do
		if [[ "$bootsplash" == "$image" ]]; then
			shouldExit=false
		fi
	done
}

# checks if image was built with bootsplashes
if [[ ! -d /bootsplash ]]; then
  echo -e "${R}${UN}IMAGE WAS BUILT WITHOUT BOOTSPLASHES. OPTION #1 WILL BREAK.${RUN}${N}"
	replace_broken=true
fi

move_images() {
	if [[ -z $(find $cros_assets -name '*.old') ]]; then
		for assets in $cros_assets $cros_assets_2; do
			for splashframe in $(find $assets -mindepth 1 -name 'boot_splash_frame*.png'); do
				mv $splashframe ${splashframe}.old
				if [[ $splashframe == *"00.png" ]]; then
					cp $1 $splashframe
				fi
			done
		done
	else
		for assets in $cros_assets $cros_assets_2; do
			cp $1 ${assets}/boot_splash_frame00.png
		done
	fi
}

replace() {
	get_installed_bootsplashes
	if [[ $shouldExit == true ]]; then
		fail "${R}Invalid filename...${N}"
	else
		move_images $bootsplash
		echo -e "${B}Replaced bootsplash!${N}"
	fi
}

replace_custom() { # this is broken rn, can someone figure out whats happening? it seems like it just doesnt replace it at all
# try using this now, obviously this won't fix it but it could help figure out what the problem is
	echo -e "${G}Enter the FULL path to the custom image!${N}"
	read -rep " > " custom_img_path
	if [ -f "$custom_img_path" ]; then
		move_images $custom_img_path
		echo -e "${B}Replaced bootsplash!${N}"
	else
    	fail "${R}The image $custom_img_path does not exist! Make sure you have the path right!${N}"
	fi
}

restore() {
	for assets in $cros_assets $cros_assets_2; do
		for splashframe in $(find $assets -mindepth 1 -name 'boot_splash_frame*.old'); do
			mv ${splashframe} ${splashframe%.*}
		done
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
	for assets in $cros_assets $cros_assets_2; do
		for splashframe in boot_splash_frame*.png; do
			cp $splashframe ${assets}/${splashframe}.old
		done
	done
	echo -e "${Y}Cleaning up!${N}"
	rm chromeos_bootsplash.zip boot_splash_frame*.png
	echo -e "${B}Done! Use option 3 (Restore stock bootsplash) to restore the stock bootsplash${N}"
}

remove() {
	echo -e "${Y}This will remove the bootsplash ENTIRELY. Use restore to fix it.${N}"
	read -p "Contnue? (y/N) " -n 1 -r
	echo   
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo -e "${Y}Removing bootsplash...${N}"
		rm "$cros_assets/boot_splash_frame*.png"
		rm "$cros_assets_2/boot_splash_frame*.png"
		echo -e "${G}Removed bootsplash!${N}"
	fi
}

if [[ $replace_broken == "true" ]]; then
	echo -e "${R}1. Replace bootsplash with modmium bootsplash${N}"
else
	echo -e "${G}1. Replace bootsplash with modmium bootsplash${N}"
fi
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
