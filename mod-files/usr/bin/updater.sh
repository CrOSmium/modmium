#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh
if [[ -d /usr/local/nix/store ]]; then
	# issues can get caused if a user has a custom shell.
	# before, this code only ran if .bashrc was sourced,
	# but the shell wouldn't open if .bashrc wasn't sourced
	# chicken and egg. we fix it here.
	if ! mountpoint -q /nix; then
		sudo mkdir -p /nix
    sudo mount --bind /usr/local/nix /nix
	fi
	sudo . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
	unset LD_LIBRARY_PATH
fi

if ! which git >/dev/null 2>&1; then
	echo -e "${R}git not installed, installing...${N}"
	source /etc/profile # required to get emerge working in mosh
	if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
		nohup dev_install --reinstall --yes >/root/.devinstall-log 2>&1 &
		echo -e "${G}Waiting for python dependencies from dev_install...${N}"
		pythonGoogleInstalled=
		while [[ $pythonGoogleInstalled != "true" ]]; do
  		python -m google >/root/.googleStatus 2>&1
  		output=$(cat /root/.googleStatus) # reason we have to do this is because python forces itself into stdout even if the output is supposed to be a variable i hate python
  		if [[ $output == *"package"* ]]; then
    		pythonGoogleInstalled=true
  		fi
  		sleep 1
		done
		# cleaning up
		rm -rf /root/.googleStatus /root/.devinstall_log
		touch /mnt/stateful_partition/.devinstall_complete
	fi
	ldconfig # reload shared libraries to include python libs
	emerge git
	cp -r /usr/local/usr/share/git-core/templates /usr/share/git-core # fix the warning about git templates being missing
fi

# -- FUNCTIONS --
BOARD="$(grep '^CHROMEOS_RELEASE_DESCRIPTION=' /etc/lsb-release | awk '{print $NF}')"
downloadImage(){
  jsonLink="https://cdn.jsdelivr.net/gh/crosbreaker/chromeos-releases-data/data.json"
  echo -e "${G}Checking crosbreaker/chromeos-releases-data for recovery image URL...${N}"
  recoveryUrl=$(curl -sL $jsonLink | jq -r --arg board $BOARD --arg ver $SELVER '
    .[$board].images // []
    | map(select(
    .channel == "stable-channel" and
    (.chrome_version | startswith($ver + "."))
    ))
    | sort_by(.last_modified)
    | last
    | .url // empty
    ')
  if [[ -n $recoveryUrl && $recoveryUrl =~ dl\.google\.com ]]; then
    echo -e "${G}Recovery URL found${N}"
    echo "$recoveryUrl" > /usr/local/.updateurl
    echo "$SELVER" > /usr/local/.updatemile
    echo -e "${N}Returning to main menu..."
    sleep 1
  else
    echo -e "${R}Recovery URL not found or invalid :(${N}"
	sleep 1
  fi
}

selectv(){
  clear
  menu_logo
  echo -e "\nWhat version would you like to update to? (Input the milestone, like '$MILESTONE')"
  echo -ne "Version ($MILESTONE): "
  stty echo
  read SELVER
  stty -echo
  downloadImage
  menu_reset
  full_menu
}
  
confupd(){
  [[ ! -f /usr/local/.updateurl ]] && echo -e "No version selected!" && sleep 1 && menu_reset && full_menu
  if [[ -d /root/.ssh ]]; then
		runscript "/usr/bin/modupdate.sh --imageurl $(cat /usr/local/.updateurl) --gitrepo git@github.com:CrOSmium/modmium"
	else
    	runscript "/usr/bin/modupdate.sh --imageurl $(cat /usr/local/.updateurl) --gitrepo https://github.com/CrOSmium/modmium"
  fi
}

legacyupd(){
    runscript /usr/bin/update-modmium.sh
    }

# -- MAIN SCRIPT --

tput civis # :whale:

menu_reset() {
    menuText="\nModmium Update Utility\n${R}For now, If you are using Userkeys, this will make ChromeOS ${UN}unbootable${RUN}.${N}\n"
    if [[ -f /usr/local/.updatemile ]]; then
      options=("Select ChromeOS Version" "Confirm Update (v$(cat /usr/local/.updatemile))" "Legacy Git Update" "Exit")
    else
      options=("Select ChromeOS Version" "Confirm Update" "Legacy Git Update" "Exit")
    fi
    functions=("selectv" "confupd" "legacyupd" "quit")
	num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
