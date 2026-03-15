#!/bin/bash
# written by mariah carey
# lxrd for extension name fetching
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
	exit 1
}
if [[ ! -f /usr/local/share/policy-test-tool/extracted.json ]]; then
	fail "${R}You didn't use policy.sh or didn't provide a policy.json to install extensions.
If you intended to do so, sign out this account or powerwash, then see the README for policy editing instructions.${N}"
fi
get_ext_name() {
	local id="$1"
	local name
	name=$(curl -sL --max-time 5 \
		"https://clients2.google.com/service/update2/crx?response=updatecheck&acceptformat=crx3&x=id%3D${id}%26uc" \
		| grep -o 'name="[^"]*"' | head -1 | sed 's/name="//;s/"//')
	[[ -z "$name" ]] && name=$(curl -sL --max-time 5 \
		"https://chrome.google.com/webstore/detail/${id}" \
		| grep -o '<title>[^<]*</title>' | head -1 | sed 's/<title>//;s/<\/title>//;s/ - Chrome Web Store//')
	[[ -z "$name" ]] && name="Unknown"
	echo "$name"
}
declare -A NAME_CACHE
echo -e "${D}Fetching extension names...${N}"
for extension in $(cat /usr/local/share/policy-test-tool/extracted.json); do
	id=$(echo "$extension" | sed 's/^.*a\///')
	NAME_CACHE[$extension]=$(get_ext_name "$id")
done
while :; do
	echo -e "${P}This is used to install your school ${UN}Chrome Web Store${RUN} extensions after running policy.sh
Already installed extensions are green, ones yet to be installed are white. You can click the links.${N}"
	installed=$(ls /home/user/*/Extensions/ 2>/dev/null | tr '\n' ' ')
	for extension in $(cat /usr/local/share/policy-test-tool/extracted.json); do
		id=$(echo $extension | sed 's/^.*a\///')
		name="${NAME_CACHE[$extension]}"
		if [[ " $installed " == *" $id "* ]]; then
			echo -e "Installed: ${B}$name${N} — $extension" # for some reason, due to how crosh handles colors, $B is green and $G is blue??? idk man just roll with it
		else
			echo -e "Not installed: $name — $extension"
		fi
	done
	echo -e "${G}Hit (Ctrl+C) to go back to MOSH${N}"
	sleep 10 
	clear
done
