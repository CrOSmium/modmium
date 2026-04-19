#!/bin/bash

# written by DMD


# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh

# -- MAIN SCRIPT --
tput civis # :whale:
milestone

menu_reset() {
	options=("1) Install Nix" "2) Go Back")
    num_options=${#options[@]}
}
menu_reset


selector() {
	sel="${options[$selected_index]}"

	case "$sel" in
		1*)
			runscript "bash /usr/bin/.nix-install.sh"
			;;
		2*)
			stty echo
			tput cnorm
			clear
			exec /usr/bin/mosh-misc.sh
	esac
}

display_menu() {
	tput sc
  menu_logo

  if [[ "$MILESTONE" == "" ]]; then
  	echo -e "${R}Uhh... how are you seeing this if ChromeOS isn't installed..?${N}"
  elif [[ "$MILESTONE" -le 131 ]]; then
    echo -e "(WARNING): you are currently on ChromeOS ${R}v$MILESTONE${N}, which is not officially supported by Modmium."
  elif [[ "$STABLEVERSIONS" =~ (^|,)"$MILESTONE"(,|$) ]]; then
  	echo -e "-- You are currently on ChromeOS ${G}v$MILESTONE${N} (Modmium-${branch}) --"
  else
    echo -e "-- You are currently on ChromeOS ${R}v$MILESTONE${N} (Modmium-${branch}-${R}untested${N}) -- [This version hasn't been tested by the Modmium devs, but it will likely still work fine.]"
  fi

  echo ""
  echo -e "This will install 'Nix', A package manager usable on Modmium, ${R}Not recommended unless you know what you're doing.${N}\nYou can use '${B}mix${N} [arg]' in a root shell to use Nix like a regular package manager like apt, or if you're just lazy.\n"
  for i in "${!options[@]}"; do
  	if [[ $i -eq $selected_index ]]; then
    	printf "\e[7m > ${options[$i]} \e[0m\n"
    else
    	printf "   ${options[$i]}      \n"
  	fi
  done
}
clear
full_menu
tput cnorm
selector
