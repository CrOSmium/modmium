#!/bin/bash
# written by mariah carey
. /usr/lib/libmosh.sh
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
	fi
	rm -rf "$_unpacked"
}
extractCoreboot
newBios=$(find ./ -name 'coreboot*.bin') # this assumes extractCoreboot was already ran
regions=("GBB" "RO_VPD" "RW_VPD")
installCbfstool(){
  pushd $(mktemp -d) &>/dev/null
  curl -LO https://mrchromebox.tech/files/util/cbfstool.tar.gz
  tar -zxf cbfstool.tar.gz
  chmod +x cbfstool
  cp ./cbfstool /usr/bin/cbfstool
  popd &>/dev/null
 }
getRegions(){
  if ! which cbfstool &>/dev/null; then
    echo -e "${B}Installing cbfstool...${N}"
    installCbfstool
  fi
  echo -e "${B}Extracting BIOS from flash...${N}"
  flashrom -r bios.bin &>/dev/null
  for region in ${regions[@]}; do
    cbfstool bios.bin read -r $region -f ${region}.bin
  done
}
flashRegions(){
  echo -e "${B}Writing VPD and GBB to clean bios...${N}"
  for region in ${regions[@]}; do
    cbfstool $newBios write -r $region -f ${region}.bin
  done
}
# hwid acts weird, so that's why we have to do it differently
setHwid(){
	echo -e "${B}Setting HWID on clean bios...${N}"
  gbb_utility bios.bin --get --hwid >hwid
  cbfstool $newBios add -n hwid -f hwid -t raw
	rm hwid
}
main(){
	getRegions
	flashRegions
	setHwid
	echo -e "${B}Cleaning up...${N}"
	for region in ${regions[@]}; do
		rm ${region}.bin
	done
	echo -e "${G}Done! \"Stock\" BIOS at ${newBios}${N}"
	# we don't rm bios.bin that way we can restore firmware if something goes wrong :pray:
}
main
