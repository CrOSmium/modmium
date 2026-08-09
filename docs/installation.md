# Installation instructions
> [!TIP]
> The "Emergency Revert" option in MOSH means keeping a firmware backup isn't *strictly necessary*, however, it is still best practice to keep one in case your VPD gets messed up somehow.
> WP (and APROV if on Ti50) **must** be disabled before installation, the script will refuse to run if it is on.

## Pros and Cons
> [!NOTE]
> If you don't understand any of this, [VT-2 installation](#vt2-installation) is significantly easier, especially the quick installer.
* VT2 Installation:
  * +: Doesn't require a linux environment to build
  * +: More convenient to install
  * -: Requires internet connection every time you install
  * -: Quick installer, while easier, does not back up your firmware.
  * -: Doesn't come with bootsplashes or policy.json pre-installed
* Recovery Image:
  * +: Once the image is created, no internet connection is required to install
  * +: Can prepare bootsplashes and policy.json
  * +: Allows custom modifications to Modmium
  * -: Requires a linux environment to build (you can use WSL if you're building on Windows. the dependencies will be the same as Ubuntu)
  * -: More complicated to install
  
> [!IMPORTANT]
> Minimum supported version is 131, issues/PRs about 130- will be ignored and closed

## VT2 Installation
> [!TIP]
> F2 is usually the key ***to the right of*** the (←)Backward/Left arrow key, usually being either (→)Forward/Right arrow or (↻)Refresh key.
>
> *This varies across devices.*
1. Boot [developer mode](https://docs.crosbreaker.com/quickstart/exploits/misc/developer-mode/).
2. Connect to the internet by pressing the wifi icon in the bottom right (don't press "Get Started").
3. Open VT2 **[Ctrl+Alt+F2]** and login as `root`, and run your chosen installer:
    * **Quick**: Run `bash <(curl -SLk modmium.dev/quick-modmium.sh)`
    > *(this won't backup your firmware to a USB, but works in one run and does almost everything for you.)*
    * **Standard**: Run `cd /usr/local; curl -LOsk modmium.dev/modmium.sh && bash modmium.sh <flags>`
4. (**Standard ONLY**) After devfw is installed, reboot, then run the command again to install Modmium to disk (this is necessary to make the rootfs read-writable).
6. Reboot (It'll probably do this for you), and it should return you to verified mode. go through OOBE as normal and you'll be enrolled with Modmium!

> [!WARNING]
> If you're using the regular modmium.sh while signed in, please make sure to eject the drive you are backing up to before running it, otherwise you may have issues.

## Recovery Image
> [!CAUTION]
> Do not use prebuilt modmium images, as they may be outdated or contain malicious scripts, if you do not want to build a recovery image, use the [VT-2 installer](#vt2-installation)

1. Flash the image (see crosbreaker docs' [flashing guide](https://docs.crosbreaker.com/quickstart/exploits/misc/flashing-guide/) for a how-to).
Of note, __before__ flashing the image FWMP must be disabled. To be sure it is, boot devmode as normal (i.e. not enrolled, powerwash if necessary).
2. Connect to the internet by pressing the wifi icon in the bottom right (don't press "Get Started").
3. open VT2 **[Ctrl+Alt+F2]** and login as `root` then run `cd /usr/local; curl -LOsk modmium.dev/fwmp.sh && bash fwmp.sh` to clear Firmware Management Parameters.
4. Run `curl -LOsk modmium.dev/modmium.sh && bash modmium.sh <flags>` to install developer firmware (devfw) & backup to a drive or directory easily. 
5. If WP is disabled, the script will prompt you to select either to backup your firmware to a drive or directory, (DRIVE IS RECOMMENDED [seriously, pick drive if you don't know what you're doing, please.], ALL DATA ON IT WILL BE WIPED). Select the USB (or directory) you want to back up to, then press enter, if everything succeeds, it will automatically reboot.
6. Enter recovery **[Esc+Refresh+Power]**.
7. Plug in the disk with Modmium on it.
8. Let it recover, then reboot.
9. Return to secure mode.
10. After it reboots, go through OOBE as normal and you'll be enrolled.

> [!NOTE]
> You still have access to VT's even in verified, and rootFS verification is disabled in verified. This is thanks to devfw allowing us to use resigned kernels and unverified root filesystems.

## Flags (ADVANCED USERS ONLY)
* `modmium.sh` flags:
  * `-u`/`--userkeys`: If you have a USB drive with your own signing keys on them, you can use it. Be sure to plug it into the chromebook before running `modmium.sh`; yes, even the second time (`-b` will be ignored if you pass `-u`.)
  * `-b`/`--backup`: default true, whether or not to create a firmware backup. pass `--nobackup` if you are absolutely certain you don't need one (We recommend you **don't** do this, but if you know what you're doing, we can't stop you).
