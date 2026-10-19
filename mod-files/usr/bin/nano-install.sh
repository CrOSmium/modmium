#!/usr/bin/env bash
# written by unixityyy

# init
source /usr/lib/libmosh.sh

# main thing
source /etc/profile # emerge breaks without this
if [[ ! -f /mnt/stateful_partition/.devinstall_complete ]]; then
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    touch /mnt/stateful_partition/.devinstall_complete
fi
ldconfig # emerge breaks without this too

echo -e "${G}Installing nano...${N}"
emerge nano
ec=$?

if [[ ${ec} == 130 ]]; then
    echo -e "${R}Install interrupted! Please try again!${N}"
elif [[ ${ec} -ne 0 ]]; then
    echo -e "${R}nano install failed!${N}"
else
    echo -e "${G}Success!"
fi
unset ec
sleep 3