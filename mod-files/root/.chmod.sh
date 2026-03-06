while :; do
	for ext in $(find /home/user/*/Extensions/ -mindepth 1); do
		chmod 000 $ext
	done
	sleep 5
done
