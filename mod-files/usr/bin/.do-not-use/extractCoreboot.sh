#!/bin/bash

# written by mariah carey
# modified by xz8f for makebackup.sh

get_hwid() { # this will be useful later
    echo "$(crossystem hwid)" # just "crossystem hwid" would probably be fine but just in case idk ill do echo
}

extractCoreboot(){
  eval $(cat /tmp/machine-info | grep customization_id)
  _board=${customization_id}
        BOARD=$_board
  _unpacked=$(mktemp -d)
        echo "Extracting coreboot image"
        if ! chromeos-firmwareupdate --unpack $_unpacked >/dev/null 2>&1; then
                if chromeos-firmwareupdate --sb_extract $_unpacked >$_unpacked/sb_extract.log 2>&1; then
                        echo "Failed to extract shellball image"
                        cat $_unpacked/sb_extract.log
                        exit 1
                fi
        fi

        if [ -d $_unpacked/models/ ]; then
                _version=$(cat $_unpacked/VERSION | grep -m 1 -e Model.*$_board -A5 |
                        grep "BIOS (RW) version:" | cut -f2 -d: | tr -d \ )
                if [ "$_version" == "" ]; then
                        _version=$(cat $_unpacked/VERSION | grep -m 1 -e Model.*$_board -A5 |
                                grep "BIOS version:" | cut -f2 -d: | tr -d \ )
                fi
                if [ -f $_unpacked/models/$_board/setvars.sh ]; then
                        _bios_image=$(grep "IMAGE_MAIN" $_unpacked/models/$_board/setvars.sh |
                                cut -f2 -d'"')
                else
                        # special case for REEF, others?
                        _version=$(grep -m1 "host" "$_unpacked/manifest.json" | cut -f12 -d'"')
                        _bios_image=$(grep -m1 "image" "$_unpacked/manifest.json" | cut -f4 -d'"')
                fi
        elif [ -f "$_unpacked/manifest.json" ]; then
                _version=$(grep -m1 -A4 "$BOARD\":" "$_unpacked/manifest.json" | grep -m1 "rw" |
                                sed 's/.*\(rw.*\)/\1/' | sed 's/.*\("Google.*\)/\1/' | cut -f2 -d'"')
                _bios_image=$(grep -m1 -A10 "$BOARD\":" "$_unpacked/manifest.json" |
                                grep -m1 "image" | sed 's/.*"image": //' | cut -f2 -d'"')
        else
                _version=$(cat $_unpacked/VERSION | grep BIOS\ version: |
                        cut -f2 -d: | tr -d \ )
                _bios_image=bios.bin
        fi
        if cp $_unpacked/$_bios_image coreboot-$_version.bin; then
                echo "Extracted coreboot-$_version.bin"
                for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0); do
                        echo "Copying coreboot-$_version.bin to $downloadsDir..."
                        cp "coreboot-$_version.bin" "$downloadsDir/coreboot/coreboot-$_version.bin"
                        mv "$downloadsDir/coreboot/coreboot-$_version.bin" "$downloadsDir/coreboot/BIOS_$(get_hwid | tr ' ' '_').bin"
                        echo "Done copying, make sure you save this backup image incase you brick your chromebook"
                done
        fi
        rm -rf "$_unpacked"
}
extractCoreboot
