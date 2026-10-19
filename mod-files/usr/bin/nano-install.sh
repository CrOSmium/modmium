#!/usr/bin/env bash
# written by unixityyy

# init
source /usr/lib/libmosh.sh

# main thing
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