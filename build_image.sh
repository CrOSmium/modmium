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
# args=$@ 
# I FUCKING HATE BASH ASLDFJNMASKLDFH;GNFGDJKLADF;NHLK;ADFNH;JKDJK;N;GKANDFGJKN WHAT DO YOU MEAN YOU JUST MAKE $@ STOP EXISTING WHEN INSIDE OF A FUNCTION??? ARE YOU STUPID??????
# after a day of thinking i realize it's because $@ is the arguments passed into the function, of which there are none unless i did something like getFlags($@). i think. lemme test it.
# yep that was it. just gonna remove this variable because it's redudant now. these comments are staying because it's funny though xD
# end of checks

# begin functions
# begin flag functions
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
	FLAGS $@ || exit $?
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
	elif [[ -n $FLAGS_image && ( $FLAGS_image == "modmium.bin" ) ]]; then
		echo -e ""$R"Input image cannot have the same name as output image."$N" Rename it to something other than "$B"modmium.bin"$N""
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
# end flag functions

# begin build functions
removeVerity(){
	if [[ -n $FLAGS_image ]]
		tempDir=$(mktemp -d)
		newImage="$tempDir"/modmium-$(basename $FLAGS_image)
		echo -e ""$G"Copying image to tempdir, "$R"this may take a while..."$N""
		cp $FLAGS_image $newImage
		sync
	else
		newImage=modmium.bin
		mv $downloadedImage $newImage
	fi
	echo -e ""$G"Setting up loop device..."$N""
	loopDev=$(losetup -Pf --show $newImage) 
	echo -e ""$G"Disabling verity..."$N""
	build-utils/ssd_util.sh -i $loopDev -r 
	echo -e ""$G"Cleaning up kernel backups..."$N""
	rm -rf cros_sign_backups
}
dropModFiles(){
	echo -e ""$G"Mounting loop device..."$N""
	mount "$loopDev"p3 mnt --mkdir
	modFiles=$(find modFiles -mindepth 1 -name "*")
	echo -e ""$G"Dropping modfiles..."$N""
	for file in $modFiles; do
		if [[ -d $file ]]; then
			:
		elif [[ -f $file ]]; then
			oldFile=$(echo $file | sed 's/modFiles/mnt/')
			if [[ -f $oldFile ]]; then
				mv $oldFile "$oldFile".old
			fi
			cp $file $oldFile
			chmod 777 $oldFile
		fi
	done

	# cleanup time!
	echo -e ""$G"Cleaning up..."$N""
	umount mnt
	losetup -d $loopDev
	if [[ -n $FLAGS_image ]]; then
		echo -e ""$G"Moving image from RAM to modmium.bin in current directory..."$N""
		mv $newImage modmium.bin
		sync
		rm -rf $tempDir mnt
	else
		rm -rf mnt
	fi
	echo -e ""$G"Finished!"$N""
}
# end build functions

# begin downloading functions
downloadImage(){
	jsonLink="https://raw.githubusercontent.com/crosbreaker/chromeos-releases-data/refs/heads/main/data.json"
}
# end downloading functions

main(){
	getFlags $@
	checkFlagValidity
	if [[ -n $FLAGS_image ]]; then
		removeVerity
		dropModFiles
	elif [[ -n $FLAGS_board && -n $FLAGS_version ]]; then
		downloadImage
		removeVerity
		dropModFiles
	fi
}
