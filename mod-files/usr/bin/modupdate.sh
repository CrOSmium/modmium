#!/bin/bash
# written by DMD

# Before you ask why i wrote this so dynamically, its because i want flexibility and also for future forks of modmium :3
# It is written as simply as I possibly could, and its as redundant as I could make it.
# This is the backend for Modmium's updater.

# -- You will need around 2-4gb free on your stateful partition for this to update properly --

TMPIMAGE="/usr/local/tmp/recovery.bin"
TMPREPO="/usr/local/tmp/overlay"
MOUNTP="/mnt/cros_overlay"


# TUI colors :D
B=$'\033[38;5;45m'
G=$'\033[38;5;46m'
Y=$'\033[38;5;220m'
R=$'\033[38;5;203m'
P=$'\033[38;5;135m'
N=$'\033[0m'
D=$'\033[1;90m'
UN=$'\033[4m' #underline
RUN=$'\033[24m' #reset underline

mounted=0

usage() {
    echo "usage: $(basename "$0") --imageurl URL --gitrepo URL [--keysdir PATH]"
    exit 1
}

IMAGEURL=""
GITREPO=""
KEYSDIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --imageurl) IMAGEURL="$2"; shift 2 ;;
        --gitrepo)  GITREPO="$2";  shift 2 ;;
        --keysdir)  KEYSDIR="$2";  shift 2 ;;
        -h|--help)  usage ;;
        *) echo "unknown argument: $1" >&2; usage ;;
    esac
done

cleanup() {
    local rc=$?
    set +e
    if (( mounted )); then # look guys i figured out how to use this
        umount "$MOUNTP" 2>/dev/null || true
    fi
    rm -f "$TMPIMAGE"
    rm -rf "$TMPREPO"
    (( rc != 0 )) && echo "something went wrong :[" >&2
    exit $rc
}

trap cleanup EXIT
trap 'exit 1' INT TERM

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

[[ -n "$IMAGEURL" ]] || { echo "--imageurl required [must be a .zip]!" >&2; exit 1; }
[[ -n "$GITREPO"  ]] || { echo "--gitrepo required" >&2; exit 1; }

for url in "$IMAGEURL" "$GITREPO"; do
    if [[ "$url" != http://* && "$url" != https://* && "$url" != git@* ]]; then
        echo "$url doesn't look like a real url!" >&2
        exit 1
    fi
done

if [[ -n "$KEYSDIR" && ! -d "$KEYSDIR" ]]; then
    echo "${R}keysdir $KEYSDIR doesn't exist${N}" >&2
    exit 1
fi

drive=$(rootdev -s -d)
echo "drive: $drive"
echo "image: $IMAGEURL"
echo "repo:  $GITREPO"

if [[ "${drive: -1}" =~ [0-9] ]]; then
    partend="p"
else
    partend=""
fi

mkdir -p /usr/local/tmp

echo "downloading image..."
curl -Lf# "$IMAGEURL" | funzip > "$TMPIMAGE" \
    || { echo "${R}download failed${N}" >&2; exit 1; }
    
pria=$(cgpt show -i 2 -P "$drive" 2>/dev/null | tr -d '[:space:]' || echo 0)
prib=$(cgpt show -i 4 -P "$drive" 2>/dev/null | tr -d '[:space:]' || echo 0)

if (( pria > prib )); then
    kerndev="${drive}${partend}4"
    rootdev="${drive}${partend}5"
    kernid=4
    oldkernid=2
else
    kerndev="${drive}${partend}2"
    rootdev="${drive}${partend}3"
    kernid=2
    oldkernid=4
fi

kstart=$(cgpt show -b -i 4 "$TMPIMAGE" | tr -d '[:space:],')
rstart=$(cgpt show -b -i 3 "$TMPIMAGE" | tr -d '[:space:],')
kcountdev=$(cgpt show -s -i $kernid "$drive" | tr -d '[:space:],')
rcountdev=$(cgpt show -s -i $(( $kernid + 1 )) "$drive" | tr -d '[:space:],') # :face_holding_back_tears: this one is opsec

echo "writing kernel -> $kerndev"
dd if="$TMPIMAGE" of="$kerndev" bs=512 skip=$kstart count=$kcountdev conv=notrunc status=progress

echo "writing rootfs -> $rootdev"
dd if="$TMPIMAGE" of="$rootdev" bs=512 skip=$rstart count=$rcountdev conv=notrunc status=progress

# A slow update is better than a broke' update!

echo "removing verity..."
dmargs=(--image "$drive" --partitions $kernid --remove_rootfs_verification --force)
[[ -n "$KEYSDIR" ]] && dmargs+=(--keys_dir "$KEYSDIR")
/usr/share/vboot/bin/make_dev_ssd.sh "${dmargs[@]}" \
    || { echo "${R}make_dev_ssd.sh failed :(${N}" >&2; exit 1; }
    
rm -f "$TMPIMAGE"

e2fsck -fy "$rootdev" || { echo "${R}e2fsck failed, image may have downloaded incorrectly!${N}" >&2; exit 1; }

echo "cloning repo..."
export PATH="/sbin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/libexec/git-core" # just in case, so we know git https will work
git clone --depth=1 "$GITREPO" "$TMPREPO" || { echo "${R}git clone failed${N}" >&2; exit 1; }
[[ -d "$TMPREPO/mod-files" ]] || { echo "${R}repo has no mod-files/ dir, are you sure you selected the right one?${N}" >&2; exit 1; }

mkdir -p "$MOUNTP"
mount -o rw "$rootdev" "$MOUNTP" || { echo "mount failed" >&2; exit 1; }
mounted=1
cp -r /root/. "$MOUNTP/root" # this is to persist /root/ through updates
modFiles=$(find "$TMPREPO/mod-files" -mindepth 1)
echo -e "${G}Dropping modfiles...${N}"
  for file in $modFiles; do
    if [[ -d $file ]]; then
      :
    elif [[ -f $file ]]; then
        oldFile=$(echo "$file" | sed "s|$TMPREPO/mod-files|$MOUNTP|")
        dir=$(dirname $oldFile)
      if [[ -f $oldFile ]]; then
        mv $oldFile "$oldFile".old
      fi
      mkdir -p $dir
      cp $file $oldFile
      chown 0:0 $oldFile
      chmod 777 $oldFile
    fi
  done
arch=$(file $MOUNTP/bin/bash | awk -F', ' '{print $2}')
cp "$TMPREPO/build-utils/lib/minioverride-${arch}.so" "$MOUNTP/lib/minioverride.so"
rm -rf $MOUNTP/root/.force_update_firmware $MOUNTP/opt/google/cr50 $MOUNTP/opt/google/ti50
branch=$(git -C "$TMPREPO/" rev-parse --abbrev-ref HEAD)
echo $branch >$MOUNTP/.branch
umount "$MOUNTP"
mounted=0
sync # :whale:

# In the future, re-adding verity could be done here, I'm too lazy to do that so someone else can.

cgpt add -P 2 -S 1 -i $kernid "$drive" \
    || { echo "${R}prioritizing new kern failed${N}" >&2; exit 1; }
cgpt add -P 0 -i $oldkernid "$drive" \
    || { echo "${R}deprioritizing old kern failed${N}" >&2; exit 1; }
echo "${G}Done, reboot to apply!${N}"