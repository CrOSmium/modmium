#!/bin/bash

B='\033[1;36m'
G='\033[1;32m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'
D='\033[1;90m'
P='\033[1;35m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline

menu_logo() {
    echo -ne "\033]0;MOSH\007"
    echo -e "Welcome to MOSH, the Modmium developer shell

If you got here by mistake, don't panic! Just close this tab and carry on.

This shell contains a list of utilities for performing various actions on a chromebook running Modmium.
"
}

fail() {
	echo -e "$1"
	sleep 3
	exit 1
}

menu_logo

if [[ ! -f /usr/local/share/policy-test-tool/extracted.json ]]; then
	fail "${R}You didn't use policy.sh or didn't provide a policy.json to install extensions.
If you intended to do so, sign out this account or powerwash, then see the README for policy editing instructions.${N}"
fi

while :; do
	for extension in $(cat /usr/local/share/policy-test-tool/extracted.json); do
		id=$(echo $extension | sed 's/^.*a\///')
		if [[ -d /home/user/*/Extensions/$id ]]; then
			echo "${G}$extension${N}"
		else
			echo "$extension"
		fi
	done
	sleep 1
	clear
	menu_logo
	echo -e "${G}This is used to install your school ${UN}Chrome Web Store${RUN} extensions after running policy.sh
Already installed extensions are green, ones yet to be installed are white. You can click the links.${N}"
done
