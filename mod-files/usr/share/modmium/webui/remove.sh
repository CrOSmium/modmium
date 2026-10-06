#!/bin/sh
set -eu

root=${1:-/}
pak="$root/opt/google/chrome/resources.pak"
webui="$root/usr/share/modmium/webui"

python3 "$webui/patch_resources.py" "$pak" --restore
if [ "$root" = / ]; then
  stop modmium-web 2>/dev/null || true
fi
rm -f "$root/etc/init/modmium-web.conf" \
  "$root/usr/bin/modmium-web" \
  "$root/usr/bin/.modmium-web-aarch64" \
  "$root/usr/bin/.modmium-web-x86-64"
rm -rf "$root/usr/share/modmium/webserver" "$webui"
