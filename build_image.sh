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
getFlags(){
	load_shflags
	# thanks sh1mmer wax.sh for teaching me how to use shflags lmao
	FLAGS_HELP="Usage:
$0 -i <path/to/recovery.bin> [flags] 
OR
$0 -b <board> -v <version> [flags]"
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
removeVerity(){
	tempDir=$(mktemp -d)
	newImage="$tempDir"/modmium-$(basename $FLAGS_image)
	echo "Copying image to /tmp, this may take a while..."
	cp $FLAGS_image $newImage
	sync
	echo "Setting up loop device..."
	loopDev=$(losetup -Pf --show $newImage) 
	echo "Disabling verity..."
	build-utils/ssd_util.sh -i $loopDev -r 
	echo "Cleaning up kernel backups..."
	rm -rf cros_sign_backups
}
dropModFiles(){
	echo -e ""$G"Mounting loop device..."$N""
	mount "$loopDev"p3 mnt --mkdir
	modDirs=$(find modFiles -maxdepth 1 -name "*" | tail -n +2)
	echo -e ""$G"Dropping modfiles..."$N""
	for dir in $modDirs; do
		cp -r $dir mnt
	done # yes i know this overwrites things and doesn't move conflicting files to file.old yet, but it's nearly 1am and i am tired. i will figure that out tomorrow
	
	# cleanup time!
	echo -e ""$G"Cleaning up..."$N""
	umount mnt
	losetup -d $loopDev
	echo -e ""$G"Moving image from RAM to modmium.bin in current directory..."$N""
	mv $newImage modmium.bin
	sync
	rm -rf $tempDir mnt
	echo -e ""$G"Finished!"$N""
}
getFlags
checkFlagValidity
if [[ -n $FLAGS_image ]]; then
	removeVerity
	dropModFiles
fi
