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
${G}dmd: \033[38;5;78mProject lead; made MOSH/libmosh (and its subMOSHes), base devfw & MPkeys manager, mix, chromeos-setdevpasswd, base ChromeOS version switcher, post \033[38;5;126mkxtzownsu\033[38;5;78m code review, and lots of small changes, and continually maintaining the project after official release [06-07-2026].${N}
${R}mariahscarycarey: ${D}(Former)${P} Lead developer; made image builder, device policy editor frontend, ChromeOS version switcher, did most bugfixing, some maintaining up until 06-17-2026 , and MANY small changes to other code.${N}
${Y}lxrd: Discovered policy-test-tool and created device policy editing script, made a script to let us stream ChromeOS updates, integrated nix into Modmium.${N}
\033[38;5;216mcodenerd87: Wrote code for restoring MPkeys, fixed devfw flashing on geralt, firmware manager${N}
\033[38;5;126mkxtzownsu: Did early code review to make sure we weren't skidding until he stepped down [05-26-2026].${N}
\033[38;5;93mxz8f: Helped with custom bootsplashes.${N}
\033[38;5;51mCasper1051, \033[38;5;93mMoonstone, \033[38;5;57mpilgorr${N}: creating the default bootsplashes.
\033[38;5;201mpers5124, \033[38;5;214mdinonuget_, \033[38;5;49mspacenerd1235, \033[38;5;118mxmb9${N}: private beta testers, found and reported lots of bugs.

${D}[ Removing this menu from Modmium is not permitted ]${N}
-- Press any key to return --
EOF
read -n 1
exit 0
}

modsplash(){
  runscript /usr/bin/modify-bootsplash.sh
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
tilingWm(){
  runscript /usr/bin/ashland.sh
}
credits(){
  runscriptnoroot creditsMenu
}
# -- MAIN SCRIPT --
tput civis # :whale:

menu_reset() {
  options=("Modify Bootsplash" "Open Cr3nroll" "${R}Emergency Revert${N}" "Manage Nix" "Manage Ashland" "Credits" "Go back")
  functions=("modsplash"  "cr3nroll" "erevert" "prenix" "tilingWm" "credits" "quit")
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
