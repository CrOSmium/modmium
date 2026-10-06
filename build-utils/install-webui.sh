#!/bin/bash
set -e

root=${1%/}
arch=$2
pakFile="$root/opt/google/chrome/resources.pak"
newBin="$root/usr/bin/.modmium-web.new"
webuiDir="$root/usr/share/modmium/webui"
trustedScripts="$root/usr/share/modmium/webserver/trusted-scripts"
trap 'rm -f "$newBin"' EXIT

cp "$root/usr/bin/.modmium-web-${arch}" "$newBin"
chown 0:0 "$newBin"
chmod 755 "$newBin"
chown 0:0 "$root/etc/init/modmium-web.conf"
chmod 644 "$root/etc/init/modmium-web.conf"
chown 0:0 "$root/usr/lib/libmosh.sh" "$root/usr/share/misc/shflags"
chmod 755 "$root/usr/lib/libmosh.sh"
chmod 644 "$root/usr/share/misc/shflags"
while IFS= read -r script; do
  [[ -n $script ]] || continue
  chown 0:0 "$root$script"
  chmod 755 "$root$script"
done < "$trustedScripts"

python3 "$webuiDir/patch_resources.py" "$pakFile"
mv -f "$newBin" "$root/usr/bin/modmium-web"
trap - EXIT
