# Installation instructions
> [!TIP]
> The "Emergency Revert" option in MOSH means keeping a firmware backup isn't *strictly necessary*, however, it is still best practice to keep one in case your VPD gets messed up somehow.
> WP (and APROV if on Ti50) **must** be disabled before installation, the script will refuse to run if it is on.

## VT2 Installation
1. Boot [developer mode](https://docs.crosbreaker.com/quickstart/exploits/misc/developer-mode/).
2. Connect to the internet by pressing the wifi icon the bottom right (don't press "Get Started").
3. Open VT2 **[Ctrl+Alt+F2]** and login as `root` then run `cd /usr/local; curl -LOsk cdn.crosbreaker.com/modmium.sh && bash modmium.sh <flags>`
4. After devfw is installed, reboot, then run the command again to install Modmium to disk (this is necessary to make the rootfs read-writable).
5. Return to secure mode.
6. After it reboots, go through OOBE as normal and you'll be enrolled.

## Recovery Image
1. Flash the image (see crosbreaker docs' [flashing guide](https://docs.crosbreaker.com/quickstart/exploits/misc/flashing-guide/) for a how-to).
Of note, __before__ flashing the image FWMP must be disabled. To be sure it is, boot devmode as normal (i.e. not enrolled, powerwash if necessary), open VT2 **[Ctrl+Alt+F2]** and login as `root` then run `cd /usr/local; curl -LOsk crosmium.dev/fwmp.sh && bash fwmp.sh`.
2. Connect to the internet by pressing the wifi icon the bottom right (don't press "Get Started").
3. Run `curl -LOsk cdn.crosbreaker.com/modmium.sh && bash modmium.sh <flags>` to install developer firmware (devfw) & backup to a drive or directory easily. 
4. If WP is disabled, the script will prompt you to select either to backup your firmware to a drive or directory, (DRIVE IS RECOMMENED [seriously, pick drive if you don't know what you're doing, please.], ALL DATA ON IT WILL BE WIPED). Select the USB (or directory) you want to back up to, then press enter, if everything succeeds, it will automatically reboot.
5. Enter recovery **[Esc+Refresh+Power]**.
6. Plug in the disk with Modmium on it.
7. Let it recover, then reboot.
8. Return to secure mode.
9. After it reboots, go through OOBE as normal and you'll be enrolled.

> [!NOTE]
> You still have access to VT's even in verified, and rootFS verification is disabled in verified. This is thanks to devfw allowing us to use resigned kernels and unverified root filesystems.
