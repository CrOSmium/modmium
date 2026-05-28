#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- FUNCTIONS --
creditsMenu(){
    cat <<EOF | xargs -0 echo -ne

███╗   ███╗ ██████╗ ██████╗ ███╗   ███╗██╗██╗   ██╗███╗   ███╗
████╗ ████║██╔═══██╗██╔══██╗████╗ ████║██║██║   ██║████╗ ████║
██╔████╔██║██║   ██║██║  ██║██╔████╔██║██║██║   ██║██╔████╔██║
██║╚██╔╝██║██║   ██║██║  ██║██║╚██╔╝██║██║██║   ██║██║╚██╔╝██║
██║ ╚═╝ ██║╚██████╔╝██████╔╝██║ ╚═╝ ██║██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝

Created by CrOSmium${D}.dev${N} and crosbreaker${D}.com${N}

Individual Credits:
${R}mariahscarycarey: ${P}Lead developer; made image builder, device policy editor frontend, ChromeOS version switcher, did most bugfixing, and MANY small changes to other code.${N}
\033[38;5;78mdmd: Project lead; made MOSH/libmosh, devfw & MPkeys manager, base ChromeOS updater, and a bunch of small changes.${N}
${Y}lxrd: Discovered policy-test-tool and created device policy editing script, made a script to let us stream ChromeOS updates, integrated nix into Modmium.${N}
\033[38;5;126mkxtzownsu: Did code review to make sure we weren't skidding until he stepped down [05-26-2026].${N}
\033[38;5;93mxz8f: Helped with custom bootsplashes.${N}
\033[38;5;94mcon: emotional support (also helped with minor bugs in image downloader)${N}
\033[38;5;51mCasper1051, \033[38;5;93mMoonstone, \033[38;5;57mpilgorr${N}: creating the default bootsplashes.

${D}[ Removing this menu from Modmium is not permitted ]${N}
-- Press any key to return --
EOF
read -n 1
exit 0
}

modsplash(){
	runscript /usr/bin/modify-bootsplash.sh
}
toggleBootPriority(){
  menu_reset
  clear
  full_menu
  intdis=$(rootdev -d)
  if (( $(cgpt show -n "$intdis" -i 2 -P) > $(cgpt show -n "$intdis" -i 4 -P) )); then
    currentKern=2
    newKern=4
  else
    currentKern=4
    newKern=2
  fi
  if echo "$intdis" | grep -q '[0-9]$'; then
      intdis_prefix="$intdis"p
	else
	  intdis_prefix="$intdis"
	fi
  cgpt add $intdis -i $currentKern -P 0 -S 1 -T 0
  cgpt add $intdis -i $newKern -P 15 -S 0 -T 15
  echo -e "${G}Done! Switched to kernel on ${intdis_prefix}${newKern}"
  sleep 3
  exit
}
toggleEnrollment(){
	runscript /usr/bin/toggle-enrollment.sh
}
cr3nroll(){
	runscript /usr/bin/cr3nroll.sh
}
erevert(){
	runscript /usr/bin/emergency-revert.sh
}
prenix(){
	runscript /usr/bin/nix-preinstall.sh
}
credits(){
	runscriptnoroot creditsMenu
}
# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
	options=("Modify Bootsplash" "Toggle Enrollment" "Open Cr3nroll" "${R}Emergency Revert${N}" "Install Nix" "Credits" "Go back")
	functions=("modsplash" "toggleEnrollment" "cr3nroll" "erevert" "prenix" "credits" "quit")
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
