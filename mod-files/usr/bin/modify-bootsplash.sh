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
echo -e "${D}${UN}This script assumes the replacement png is /root/.modmium_bootsplash.png
If this is not the case, hit (Ctrl+C) to exit.${N}${RUN}"

replace() {
	for splashframe in $(find /usr/share/chromeos-assets/images_100/percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv $splashframe "$splashframe".old
		if [[ $splashframe == *"00.png" ]]; then
			cp /root/.modmium_bootsplash.png $splashframe
		fi
	done
	echo -e "${G}Replaced bootsplash!${N}"
}

restore() {
	for splashframe in $(find /usr/share/chromeos-assets/images_100_percent -mindepth 1 -name 'boot_splash_frame*.png'); do
		mv "$splashframe".old "$splashframe"
	done
	echo -e "${G}Restored bootsplash!${N}"
}

echo "${G}
1. Replace bootsplash
2. Restore normal bootsplash
${N}"

read -rep "Choose an option: " choice

if [ "$choice" == "1" ]; then
	replace
elif [ "$choice" == "2" ]; then
	restore
else
	echo -e "Invalid option, select either 1 (restore) or 2 (replace)"
fi
sleep 2
return
