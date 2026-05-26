#!/bin/bash
# written by mariah carey
# HEAVILY inspired by kernver.sh by ading2210, massive credit to him

set -eo pipefail

export PATH="/sbin:$PATH"

stream_zip() {
  local img_url="$1"
  curl -s -L "$img_url" | python3 -c "
import sys, zlib, struct

stdin  = sys.stdin.buffer
stdout = sys.stdout.buffer

header = stdin.read(30)
if header[0:4] != b'PK\x03\x04':
    sys.exit('error: not a ZIP local file header')

fname_len = struct.unpack_from('<H', header, 26)[0]
extra_len = struct.unpack_from('<H', header, 28)[0]
stdin.read(fname_len + extra_len)

d = zlib.decompressobj(-zlib.MAX_WBITS)
try:
    while True:
        chunk = stdin.read(1024 * 1024)
        if not chunk:
            break
        stdout.write(d.decompress(chunk))
        stdout.flush()
except BrokenPipeError:
    pass
" 2>/dev/null
}

parse_partition() {
  local img_bin="$1"
  local part_num="$2"
  fdisk -l "$img_bin" 2>/dev/null \
    | grep -E "^${img_bin}p?${part_num}([^0-9]|$)"
}

parse_sector() {
  local line="$1"
  local field="$2"
  echo "$line" | awk -v field="$field" '{
    n = 0
    for (i = 2; i <= NF; i++) {
      if ($i ~ /^[0-9]+$/) nums[++n] = $i
    }
    if (field == "start")   print nums[1]
    if (field == "end")     print nums[2]
    if (field == "sectors") print nums[3]
  }'
}

extract_partitions() {
  local img_url="$1"
  local img_bin="gpt_header.bin"
  local kernel_out="kernel.bin" # replace with ${intdis}${intdis_prefix}${kernnum} in the full script
  local rootfs_out="rootfs.img" # replace with ${intdis}${intdis_prefix}${rootnum} in the full script

  echo "Fetching partition table..."
  truncate -s 10G "$img_bin" # this is needed because fdisk will freak out about the file being too small
  # it doesn't actually use 10GB of physical space though so it's fine xD

  { stream_zip "$img_url" || true; } \
    | dd of="$img_bin" iflag=fullblock bs=1M count=2 conv=notrunc 2>/dev/null

  local fdisk_kern fdisk_root
  fdisk_kern="$(parse_partition "$img_bin" 4)"
  fdisk_root="$(parse_partition "$img_bin" 3)"

  local kern_start kern_sectors root_start root_sectors
  kern_start="$(parse_sector   "$fdisk_kern" start)"
  kern_sectors="$(parse_sector "$fdisk_kern" sectors)"
  root_start="$(parse_sector   "$fdisk_root" start)"
  root_sectors="$(parse_sector "$fdisk_root" sectors)"

  if [ -z "$kern_start" ] || [ -z "$root_start" ]; then
    echo "error: could not parse partition layout" >&2
    rm -f "$img_bin"
    return 1
  fi

  rm -f "$img_bin"

  echo "Streaming rootfs to $rootfs_out..."
  { stream_zip "$img_url" || true; } \
    | dd of="$rootfs_out" iflag=fullblock,skip_bytes,count_bytes \
        bs=4M \
        skip="$(( root_start * 512 ))" \
        count="$(( root_sectors * 512 ))" \
        2>/dev/null

  echo "Streaming kernel to $kernel_out..."
  { stream_zip "$img_url" || true; } \
    | dd of="$kernel_out" iflag=fullblock,skip_bytes,count_bytes \
        bs=4M \
        skip="$(( kern_start * 512 ))" \
        count="$(( kern_sectors * 512 ))" \
        2>/dev/null

  echo "Done."
}

if [ -z "$1" ]; then
  echo "Usage: $0 <recovery_image_url>"
  exit 1
fi

extract_partitions "$1"
