## Installation instructions
1. Flash the image (see crosbreaker docs' [flashing guide](https://docs.crosbreaker.com/quickstart/exploits/misc/flashing-guide/) for a how-to).
Of note, __before__ flashing the image FWMP must be disabled. To be sure it is, boot devmode as normal (i.e. not enrolled, powerwash if necessary), open VT2 **[Ctrl+Alt+F2]** and login as `root` then run `bash <(curl -Lsk crosmium.dev/fwmp.sh)`.
2. Run `curl -LOsk cdn.crosbreaker.com/modmium.sh && bash modmium.sh <flags>` to install developer firmware (devfw) & backup to a drive or directory easily. 
3. If WP is disabled, the script will prompt you to select either to backup your firmware to a drive or directory, (DRIVE IS RECOMMENED [seriously, pick drive if you don't know what you're doing, please.], ALL DATA ON IT WILL BE WIPED). Select the USB (or directory) you want to back up to, then press enter, if everything succeeds, it will automatically reboot.
> [!TIP]
> The "Emergency Revert" option in MOSH will mean that keeping a firmware backup isn't *strictly* necessary, however, it is still best practice to keep one in case your VPD gets messed up somehow.
4. Enter recovery **[Esc+Refresh+Power]**.
5. Plug in the disk with modmium on it.
6. Let it recover, then reboot.
7. Return to secure mode.
8. After it reboots, go through OOBE as normal and you'll be enrolled.
> [!NOTE]
> You still have access to VT's even in verified, and rootFS verification is disabled in verified. This is thanks to devfw allowing us to use resigned kernels and unverified root filesystems.
