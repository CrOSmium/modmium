# QOL scripts to test modmium.bin. DELETE BEFORE RELEASE.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, elevating with sudo..."
	 sudo "$0" "$@"
	 exit $?
fi
if [[ -z "$1" ]]; then
	echo "pass image to mount as only arg"
	exit 1
fi
loopDev=$(losetup -Pf --show "$1")
mount "$loopDev"p3 mnt --mkdir
