#!/bin/bash
extsInstalled=false
while :; do
	for dir in $(find /home/user/*/Extensions/ -mindepth 1 -maxdepth 1); do
		if [[ -d $dir ]]; then
			extsDownloading=true
		fi
	done
	if [[ $extsDownloading == true ]]; then
		sleep 20 # extensions usually take about 10 seconds to install
		extsInstalled=true
	fi
	if [[ $extsInstalled == true ]]; then
		for ext in $(find /home/user/*/Extensions/ -mindepth 1); do
			chmod 000 $ext
		done
		exit 0
	else
		:
	fi
done
