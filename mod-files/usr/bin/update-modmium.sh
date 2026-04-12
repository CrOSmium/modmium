#!/bin/bash
# written by mariah carey

# colors
B='\033[38;5;45m'
G='\033[38;5;46m'
Y='\033[38;5;220m'
R='\033[38;5;203m'
P='\033[38;5;135m'
N='\033[0m'
D='\033[1;90m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline

branch=$(cat /.branch)

fail() {
	echo -e "$1"
	sleep 3
	exit 1
}

dropModFiles() {
	modFiles=$(find /mnt/stateful_partition/git/modmium/mod-files -mindepth 1 -name "*")
	for file in $modFiles; do
		if [[ -d $file ]]; then
			:
		elif [[ -f $file ]]; then
			realFile=$(echo "$file" | sed 's/^.*mod-files//')
			mkdir -p $(dirname $realFile)
			cp $file $realFile
			chown 0:0 $realFile
			chmod 777 $realFile
		fi
	done
	if [[ -d /usr/local/share/policy-test-tool ]]; then
		cp /root/.policy-test-tool/* /usr/local/share/policy-test-tool
	fi
}

update() {
	clear
	export PATH="/sbin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/libexec/git-core" # just in case, so we know git https will work
	mkdir -p /mnt/stateful_partition/git
	cd /mnt/stateful_partition/git
	if [[ -d /root/.ssh ]]; then
		git clone --depth 1 -b $branch --single-branch git@github.com:crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}"
	else
		git clone --depth 1 -b $branch --single-branch https://github.com/crosmium/modmium.git || fail "${R}Failed to clone repository, exiting...${N}"
	fi
	echo -e "${G}Successfully cloned repository!${N} Dropping new files..." 
	dropModFiles || fail "${R}Failed to drop updated files, please make an issue report on https://github.com/crosmium/modmium with details of any changes you made if applicable...${N}"
	echo -e "${G}Done! Cleaning up...${N}"
	rm -rf /mnt/stateful_partition/git/modmium
	sync # this is for all the times i changed stuff locally and didn't sync and suddenly it didn't boot - dmd
	sleep 3 
	return
}

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

update
