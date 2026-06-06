# IF YOUR DISTRO HAS AN OUTDATED VBOOT-UTILS OR DOESN'T HAVE IT, SEE [COMPILATION INSTRUCTIONS](./vboot-utils.md)

## Arch Linux:
```bash
yay -S --needed acpica coreutils curl jq libarchive pv util-linux vboot-utils wget
yay -S inkscape # Optional, only required for custom bootsplash
```

## Debian (requires sid repo)
```bash
sudo apt update
sudo apt install -y acpica-tools coreutils curl jq libarchive-tools pv sed util-linux vboot-utils wget
sudo apt install -y inkscape # Optional, only required for custom bootsplash
# note, you may also have to run this if bsdtar is not found
alias bsdtar=tar
```
