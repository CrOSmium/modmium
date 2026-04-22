# this file *should* be able to reconstruct a firmware backup by using https://github.com/coreboot/coreboot/blob/main/util/chromeos/crosfirmware.sh and fixing the vpd and gbb
# ill work on this when I have time


# reminders:
# futility gbb -s --flags=0x80b1 filename.bin
# futility gbb -s --hwid="HWID" filename.bin


#get_codename() {
#    hwidp="$1"
    # ok I need to switch to normal chromeos to do some testing for getting the HWID. This function will just get the HWID, then remove whatever comes after the space and anything after "-" if there is one 
#}

# ^^^ nvm I didnt wanna have to do setup
get_userhwid_img() {
    read -p "enter your device codename as it is on https://cros.tech: " usercodename
    if [[ "$usercodename" == "" ]]; then
        echo "please enter a codename."
        sleep 5
        fail # :whale:
    fi
    if [[ ! -f "crosfirmware.sh" ]]; then
        echo "getting crosfirmware.sh..."
        curl -fLO https://raw.githubusercontent.com/coreboot/coreboot/36f0b1257009e6acd314d319226afdc2fe7f234c/util/chromeos/crosfirmware.sh || { # thanks con lol
        echo "failed to download, make sure you are on a network with githubusercontent.com unblocked"
        exit 1
    }
    fi
    bash crosfirmware.sh "$usercodename"s 
}
# TODO: actually modify the image and ask if the user wants to flash