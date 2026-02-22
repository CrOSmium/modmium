# QOL scripts to test modmium.bin. DELETE BEFORE RELEASE.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root, elevating with sudo..."
	 sudo "$0" "$@"
	 exit $?
fi
umount mnt && rm -rf mnt
losetup -D
