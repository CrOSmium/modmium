murkmod walked, so we could fly

## usage instructions:
0. Disable WP on your chromebook (see [MrChromebox Guide](https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html) for more info). If interested in keeping enterprise extensions (but with the ability to disable them), read the policy editor instructions before continuing!
1. Connect to internet in the quick settings (bottom right), then open VT2 **[Ctrl+Alt+F2]** and login as `root`
2. Run `curl -LOsk cdn.crosbreaker.com/modmium.sh && bash modmium.sh <flags>` to install developer firmware (devfw) & backup to a drive or directory easily. 
3. If WP is disabled, the script will prompt you to select either to backup your firmware to a drive or directory, (DRIVE IS RECOMMENED [pick drive if you don't know what you're doing, please.], ALL DATA ON IT WILL BE WIPED). Select the USB (or directory) you want to back up to, then press enter, if everything succeeds, it will automatically reboot.
4. **BACK UP THE FIRMWARE DUMP TO YOUR PC AND/OR CLOUD**
5. Build the image
```sh
git clone https://github.com/CrOSmium/modmium && cd modmium 
# if you want to download an image and autobuild
./build_image.sh -b <board> -v <version>
# if you want to use a local image (non-destructive)
./build_image.sh -i /path/to/image.bin
# note that -i and -b/-v are MUTUALLY EXCLUSIVE. it's one or the other, the script will refuse to run if you pass both
# (You can also use -u for userkeys, which allows you to sign the image with your own keys instead of devkeys)
```

6. Flash the image (see crosbreaker docs' [flashing guide](https://docs.crosbreaker.com/quickstart/exploits/misc/flashing-guide/) for a how-to).
Of note, __before__ flashing the image FWMP must be disabled. To be sure it is, boot devmode as normal (i.e. not enrolled, powerwash if necessary), open VT2 **[Ctrl+Alt+F2]** and login as `root` then run `bash <(curl -Lsk crosmium.dev/fwmp.sh)`.
7. Enter devmode recovery
8. Plug in the disk with modmium on it.
9. Let it recover, then reboot.
10. Return to secure mode.
11. After it reboots, go through OOBE as normal and you'll be enrolled.
You still have access to VT's even in verified, and rootFS verification is disabled in verified. This is thanks to devfw allowing us to use resigned kernels and unverified root filesystems.

## policy editor instructions
0. (Optional) Before installing modmium, enroll and login to your enterprise account, then export json from chrome://policy. Add `-j /path/to/policies.json` when building the image, or name the file `policy.json` and place it in `mod-files/root` 
You'll want to do this if you want your enterprise's extensions to install, for example if they have monitoring software and would get suspicious if you didn't have it.
1. Install and boot modmium in verified (see above instructions).
2. Open VT2 once __fully enrolled__.
3. Run `bash policy.sh` and enter your enterprise email when prompted.
4. When the fake device management server starts, go back to VT1 and sign in with the same email.
5. After you're logged in, go back to VT2 and hit Ctrl+C

After you sign in to an account, hit **[Ctrl+Alt+T]** to open MOdmium SHell (MOSH). In MOSH, there's various utilities, such as root/chronos shell, and the modmium updater. **Some utilities aren't in MOSH, such as the policy editor (see above)**. <br>
Speaking of which; if you pass policy.json your enterprise extensions will install, but __not be force-installed__ (i.e. you can press the switch to toggle them off in chrome://extensions).



## REPO LAYOUT

(thank you mariah!)
* `bootsplash/`
   * contains default bootsplash SVG files which can be converted into PNG files to be used by modify-bootsplash.sh in MOSH.
* `build-utils/`
   * contains scripts, libraries, and signing keys used for building the image
* `mod-files/`
   * is a rootfs overlay (for example, `modFiles/usr/bin/crosh` is mosh (modmium shell)
   * `build_image.sh` already handles moving replaced files to `$oldFile.old`, so you don't have to worry about overwriting things in case they need to be called by the modfile (for example `modFiles/sbin/chromeos_startup` needs to call the normal chromeos\_startup, which is at `/sbin/chromeos_startup.old`)
* `build-image.sh`
   * builder for installing modmium to recovery images.
* `docs/DEPENDENCIES.md`
   * the dependencies required to build modmium on various linux distros.
* `modmium.sh`
   * the devfw installation helper (will be hosted on crosbreaker cdn).

about the code of conduct:
Note from mariah scary. "For the love of everything don't use this to cheat. I personally made this out of a passion for learning and programming (it's by far been the most difficult, fun, and largest project I've worked on). 
Your minds are incredible things, don't let them go to waste please."
