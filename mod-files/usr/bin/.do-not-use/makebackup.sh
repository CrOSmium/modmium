#!/bin/bash

# reminders:
# futility gbb -s --flags=0x80b1 filename.bin
# futility gbb -s --hwid="HWID" filename.bin
# vpd -f filename.bin -i RW_VPD -s check_enrollment=1

get_hwid() { # this will be useful later
    echo "$(crossystem hwid)" # just "crossystem hwid" would probably be fine but just in case idk ill do echo
}

get_codename() {
    hwid="$(get_hwid)"
    echo "${hwid%% *}"
}

get_img() {
    bash extractCoreboot.sh
}

for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0); do
    corebootbin="$downloadsDir/coreboot/BIOS_*.bin" # I gtg ill work on this more later today if I have time
done