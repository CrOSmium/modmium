#!/bin/bash
set -e

MARKER="/usr/local/.nix_install_done"

if [ -f "$MARKER" ]; then
  echo "Nix has already been installed. To reinstall, run:"
  echo "rm -rf $MARKER"
  exit 0
fi

mkdir -p /usr/local/tmp
mkdir -p /usr/local/nix
mkdir -p /nix
mount --bind /usr/local/nix /nix

groupadd -g 30000 nixbld 2>/dev/null || true
for i in $(seq 1 32); do
  useradd -u $((30000 + i)) -g nixbld -G nixbld \
    -d /var/empty -s /sbin/nologin \
    -c "Nix build user $i" nixbld$i 2>/dev/null || true
done

curl -L https://nixos.org/nix/install -o /usr/local/tmp/install.sh && cp /usr/bin/.mix /usr/bin/mix
TMPDIR=/usr/local/tmp sh /usr/local/tmp/install.sh
sync

touch "$MARKER"