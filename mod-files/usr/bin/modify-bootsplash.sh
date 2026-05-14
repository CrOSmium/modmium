#!/bin/bash
# originally written by xz8f
# partially rewritten by mariah carey for MOSH

source /usr/lib/libmosh.sh

fail() {
	echo -e "$1"
	for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0); do
		sudo chown -R chronos:chronos "$downloadsDir/bootsplashes"
	done
	sleep 3
	return
}
cros_assets="/usr/share/chromeos-assets/images_100_percent"
cros_assets_2="/usr/share/chromeos-assets/images_200_percent"

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
	replace_broken="$FLAGS_TRUE"
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

menu_reset(){
	options=("${G}Replace bootsplash with modmium bootsplash${N}" "${G}Replace bootsplash with custom image${N}" "${G}Restore stock bootsplash${N}" "${G}Download stock bootsplash and save to backup${N}" "${G}Remove bootsplash${N}" "Go Back")
	functions=("replace" "replace_custom" "restore" "download_backup" "remove" "quit")
	if [[ $replace_broken == $FLAGS_TRUE ]]; then
		for array in options functions; do
			declare -n target=$array
			target=("${target[@]:1}")
		done
	fi
	menuText=$(cat <<EOF
${P}+##############################################+
| Bootsplash Replacer                          |
| -------------------------------------------- |
| Replaces the stock ChromeOS bootsplash       |
+##############################################+${N}
${D}(Hit Ctrl+C to return to MOSH)${N}
EOF
	)
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
