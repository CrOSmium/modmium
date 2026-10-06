#!/bin/sh
set -eu
python3 /usr/share/modmium/webui/patch_resources.py /opt/google/chrome/resources.pak --restore
stop modmium-web 2>/dev/null || true
rm -f /etc/init/modmium-web.conf /usr/bin/modmium-web /usr/bin/.modmium-web-aarch64 /usr/bin/.modmium-web-x86-64
rm -rf /usr/share/modmium/webserver /usr/share/modmium/webui /root/gui
