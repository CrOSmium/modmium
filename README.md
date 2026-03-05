murkmod walked, so we could fly

## (unfinished) usage instructions:
0. Disable WP on your chromebook (see [MrChromebox Guide](https://docs.mrchromebox.tech/docs/firmware/wp/disabling.html) for more info)
1. Build the image
```sh
git clone --recursive https://github.com/CrOSmium/modmium && cd modmium # recursive because we'll add nectar as a *submodule* instead of just copy-pasting the files
# if you want to download an image and autobuild
./build_image.sh -b <board> -v <version>
# if you want to use a local image (non-destructive)
./build_image.sh -i /path/to/image.bin
# note that -i and -b/-v are MUTUALLY EXCLUSIVE. it's one or the other, the script will refuse to run if you pass both
```
2. Flash the image (see crosbreaker docs' [flashing guide](https://docs.crosbreaker.dev/quickstart/exploits/misc/flashing-guide/) for a how-to).
Of note, __before__ flashing the image FWMP must be disabled. To be sure it is, boot devmode as normal, open vt2 **[Ctrl+Alt+F2]** and login as `root` then run the following commands:
```bash
device_management_client --action=remove_firmware_management_parameters 
device_management_client --action=set_firmware_management_parameters --flags=0x0000
```
3. Enter devmode recovery
4. Plug in the disk with modmium
5. Let it recover, then reboot (keep the USB in!)
6. Hit Ctrl+D
7. Connect to internet in the quick settings (bottom right), then open vt2 **[Ctrl+Alt+F2]** and login as `root`
8. run `bash <(curl -Lsk cdn.crosbreaker.dev/modmium.sh)` 
9. If WP is disabled, the script will prompt you to select either to backup your firmware to a drive or directory, (DRIVE IS RECOMMENED [pick drive if you don't know what you're doing, please.], ALL DATA ON IT WILL BE WIPED). Select the USB (or directory) you want to back up to, then press enter, if everything succeeds, it will automatically reboot you into verified.
10. **BACK UP THE FIRMWARE DUMP TO YOUR PC AND/OR CLOUD**
11. After it reboots, go through OOBE as normal and you'll be enrolled.
You still have access to VT's even in verified, and how rootfs verification is disabled in verified. This is thanks to dev firmware allowing us to use resigned kernels and unverified rootfs's.

## policy editor instructions
0. (Optional) Before installing modmium, enroll and login to your school account, then export json from chrome://policy. Place it in mod-files/root/ and rename it to policy.json (do this if you want your school's extensions to install, for example if they have monitoring software and would get suspicious if you didn't have it). (NOT IMPLEMENTED YET. WILL DO WHEN I GET HOME)
1. Install and boot modmium in verified (see above instructions)
2. Open VT2
3. Run `bash policy.sh` and enter your school email when prompted.
4. When the fake device management server starts, go back to VT1 and sign in with the same email.
5. After you're logged in, go back to VT2 and hit Ctrl+C
### device policy instructions (optional) (placeholder)
1. Run `bash device.sh enable` (will remove kiosk apps until disabled)
2. To undo, run `bash device.sh disable`

After you sign in to an account, hit **[Ctrl+Alt+T]** to open MOdmium SHell (MOSH). In MOSH, there's various utilities, such as root/chronos shell, ~~a policy editor (WIP)~~ (moved to outside of MOSH due to technical limitations, see above), extension disabler, and modmium updater (NOTE, will curl repo locally [we'll make a release and it'll curl the latest release's source code]), and install modFiles to rootfs. i can code that later). 

## REPO LAYOUT

(thank you mariah!)
* `build-utils/`
   * contains scripts/libraries used for building the image
* `modFiles/`
   * is a rootfs overlay (for example, `modFiles/usr/bin/crosh` is mosh (modmium shell)
   * `build_image.sh` already handles moving replaced files to `$oldFile.old`, so you don't have to worry about overwriting things in case they need to be called by the modfile (for example `modFiles/sbin/chromeos_startup` needs to call the normal chromeos\_startup, which is at `/sbin/chromeos_startup.old`)
* `build_image.sh`
   * the actual image builder. autobuilding will be added later, since it'll be pretty trivial to implement.
-------------
#### copy-pasted from the discussion in crosbreaker dev:

### maria:
> people using it should be unenrolled with WP off.
> from there, we can have the readme say to plug in a usb (and have a script ask which usb to back up to, just searching /dev/sd\*), then curl a script which will run make dev ssd and make dev firmware automatically, as well as format the selected usb to vfat then put the firmware backup on it.
> similar to mrchromebox script in that regard.
> it'll also set disable dev request to 1.
> from there readme will say to reboot and enroll in verified mode, plug in the usb, then curl the script again (we can have it check the fw type [normal or developer]) to back up the policy file to the usb
### maria:
> this is setup before building the image
> once you have the policy file, you can get the policy json from chrome://policy, and put that on the usb too
> then finally it'll be able to take the policy json and policy file to use integrated policyedit, build the image like normal, and drop the modded policy files in /root
> then we can just have a daemon similar to murkmod, it'll check for a policy file and public key in /var/lib/devicesettings/ every 15 seconds, and if it exists, overwrite it with the ones in /root 
> obviously this is all just conceptual, not even psuedocode, but that's the outline for how it'll work imo
> any suggestions, critiques, or otherwise?
(there was no response)

### Notes from DMD:
> The project will likely have instructions, or even automate getting your device into DevFW, and modmium will able to spoof the rest whilst keeping developer features (like what murkmod does)
## I have confirmed that booting verified with DevFW does still report `Verified` in GAC.. for some reason.
