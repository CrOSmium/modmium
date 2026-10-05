#!/bin/bash
set -e

root=${1%/}
arch=$2
pakFile="$root/opt/google/chrome/resources.pak"
newBin="$root/usr/bin/.modmium-web.new"
webuiDir="$root/usr/share/modmium/webui"
trap 'rm -f "$newBin"' EXIT

cp "$root/usr/bin/.modmium-web-${arch}" "$newBin"
chown 0:0 "$newBin"
chmod 755 "$newBin"
chown 0:0 "$root/etc/init/modmium-web.conf"
chmod 644 "$root/etc/init/modmium-web.conf"

python3 "$webuiDir/patch_resources.py" "$pakFile"
mv -f "$newBin" "$root/usr/bin/modmium-web"
trap - EXIT
