#!/bin/bash
# once again, a conceptual overview for now, seeing as we don't want to write a bunch of code for nothing if ts gets serverside patched by the big Goog :fanxql:

# pre-flight checklist
if [ "$(basename $(echo $PWD))" != "modmium" ]; then
	echo "Please run this script in the cloned directory (modmium/)"
	exit 1
fi
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, elevating with sudo..."
	 sudo "$0" "$@"
	 exit $?
fi
source ./build-utils/common_modmium.sh
args=$@ # I FUCKING HATE BASH ASLDFJNMASKLDFH;GNFGDJKLADF;NHLK;ADFNH;JKDJK;N;GKANDFGJKN WHAT DO YOU MEAN YOU JUST MAKE $@ STOP EXISTING WHEN INSIDE OF A FUNCTION??? ARE YOU STUPID??????
# end of checks

# begin functions
get_flags(){
	load_shflags
	# thanks sh1mmer wax.sh for teaching me how to use shflags lmao
	FLAGS_HELP="Usage: $0 -i <path/to/recovery.bin> [flags] or $0 -b <board> [flags]"
	DEFINE_string image "" "Path to recovery image (use if not autobuilding)" "i" 
	DEFINE_string board "" "Name of board to autobuild (use if not manual building)" "b"
	DEFINE_string version "" "MILESTONE of version to autobuild (use if not manual building)" "v"
	FLAGS $args || exit $?
	if ! [[ 
		( -z $FLAGS_board && -z $FLAGS_version && -n $FLAGS_image ) || 
		( -n $FLAGS_board && -n $FLAGS_version && -z $FLAGS_image ) 
	]]; then
    flags_help
    exit 1
	fi
}

checkFlagValidity(){
	if [[  -n $FLAGS_image  && ! ( -f $FLAGS_image ) ]]; then
		echo -e ""$R"File not found"$N", please provide a path to an actual recovery image."
		exit 1
	fi
	if [[ -n $FLAGS_version && ! ( $FLAGS_version =~ ^[0-9]+$ ) ]]; then
		echo -e ""$R"Version not a natural number"$N", please provide chromeOS "$B"MILESTONE"$N" you want to build."
		exit 1
	fi
	if [[ -n $FLAGS_board ]]; then
		local boardInList=0
		for board in $boards; do
			if [[ "$FLAGS_board" == "$board" ]]; then
				boardInList=1
			fi
		done
		if [[ $boardInList != 1 ]]; then
			echo -e ""$R"Invalid board name."$N" See "$B"https://dl.crosbreaker.dev/recovery-images"$N" for a complete list."
			exit 1
		fi
	fi
}
remove_verity(){
	local loopDev=$(losetup -Pf --show ${FLAGS_image})
}
get_flags
checkFlagValidity
