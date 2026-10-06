#!/bin/bash
set -e
d=/root/gui
arch=$(arch | sed 's/_/-/')
[[ $arch == *ARM* ]] && arch=aarch64
bin=/usr/bin/.modmium-web.new
trap 'rm -f "$bin"' EXIT
cp "/usr/bin/.modmium-web-$arch" "$bin"
cp "$d/modmium-web.conf" /etc/init/modmium-web.conf
chown 0:0 "$bin" /etc/init/modmium-web.conf /usr/lib/libmosh.sh /usr/share/misc/shflags
chmod 755 "$bin" /usr/lib/libmosh.sh
chmod 644 /etc/init/modmium-web.conf /usr/share/misc/shflags
while IFS= read -r script; do
  [[ -n $script ]] || continue
  chown 0:0 "$script"
  chmod 755 "$script"
done < /usr/share/modmium/webserver/trusted-scripts
python3 /usr/share/modmium/webui/patch_resources.py /opt/google/chrome/resources.pak
mv -f "$bin" /usr/bin/modmium-web
trap - EXIT
if status modmium-web 2>/dev/null | grep -q running; then
  if [[ $MOSH_FRONTEND == gui ]]; then
    nohup /bin/sh -c 'sleep 1; restart modmium-web' >/dev/null 2>&1 &
  else
    restart modmium-web
  fi
else
  start modmium-web
fi
