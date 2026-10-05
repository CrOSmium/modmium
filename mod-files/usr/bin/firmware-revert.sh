#!/bin/bash
# Written by codenerd87 for modmium
fail(){
    printf "An error has occured. This script is scary so join https://discord.gg/ATmWKdEUfC for support.\n"
    printf "$1\n"
    exit
}

echo "Modmium stock firmware restore script by codenerd87"
echo "Script date: 5/27/26"
workdir=$(mktemp -d) || fail "Failed to make tmp dir"
cd ${workdir}
# model=$(cat /tmp/machine-info | grep customization_id | sed 's/customization_id=//; s/"//g' | tr '[:upper:]' '[:lower:]') # Extends support to include super old chromeos versions where the --model argument is required
chromeos-firmwareupdate -m output --output_dir ${workdir} || fail "Failed to extract firmware shellball"
rm ec.bin bios.bin #we must save 16mb ram :whale:
echo "Reading old bios"
flashrom -r oldbios.bin || fail "Failed to read current bios."

echo "Extracting VPD from current bios"
cbfstool oldbios.bin read -r RO_VPD -f rovpd.bin || fail "Failed to extract RO_VPD"
cbfstool oldbios.bin read -r RW_VPD -f rwvpd.bin || fail "Failed to extract RW_VPD"
echo "Injecting VPD into new bios"
cbfstool image.bin write -r RO_VPD -f rovpd.bin || fail "Failed to inject RO_VPD"
cbfstool image.bin write -r RW_VPD -f rwvpd.bin || fail "Failed to inject RW_VPD"

echo "VPD successfully transplated"

echo "Transplanting HWID"
futility gbb oldbios.bin -g --hwid | sed "s/hardware_id: //" > hwid.txt || fail "Failed to extract HWID"
futility gbb image.bin -s --hwid="$(cat hwid.txt)" || fail "Failed to inject HWID"

echo "HWID successfully transplated"

echo "Setting GBB flags to 0xa0b1"
futility gbb image.bin -s --flags=0xa0b1 || fail "Failed to set GBB flags"

echo "Flashing new bios"
flashrom -w image.bin || fail "Uh oh, flash failed."
echo "Firmware flashed successfully!"
