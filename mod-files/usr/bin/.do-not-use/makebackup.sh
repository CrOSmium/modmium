# this file *should* be able to reconstruct a firmware backup by using https://github.com/coreboot/coreboot/blob/main/util/chromeos/crosfirmware.sh and fixing the vpd and gbb
# ill work on this when I have time

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
# ^^^ nvm I didnt wanna have to do setup
get_img() {
    if [[ ! -f "crosfirmware.sh" ]]; then
        echo "getting crosfirmware.sh..."
        curl -fLO https://raw.githubusercontent.com/coreboot/coreboot/36f0b1257009e6acd314d319226afdc2fe7f234c/util/chromeos/crosfirmware.sh || { # thanks con lol
        echo "failed to download, make sure you are on a network with githubusercontent.com unblocked"
        exit 1
    }
    fi
    bash crosfirmware.sh "$(get_codename)" # I may just modify crosfirmware.sh and only get the bare minimum to extract the image so theres less dependencies
}
# TODO: actually modify the image and ask if the user wants to flash