# this file *should* be able to reconstruct a firmware backup by using https://github.com/coreboot/coreboot/blob/main/util/chromeos/crosfirmware.sh and fixing the vpd and gbb
# ill work on this when I have time


call_codename() {
    hwidp="$1"
    # ok I need to switch to normal chromeos to do some testing for getting the HWID. This function will just get the HWID, then remove whatever comes after the space and anything after "-" if there is one 
}