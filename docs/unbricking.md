## The problem
If you enroll a Chromebook while using Modmium and your installation later becomes corrupted to the point that it can no longer boot, recovering with the Modmium recovery image will no longer be possible because FWMP (Firmware Management Parameters) can restrict booting developer images.

If you obtain code execution (non dev+reco), it's fairly trivial to clear FWMP and restore the ability to boot the recovery image.
## Getting code execution
Thanks to the GBB flags set by `modmium.sh`, shims can be booted with **[Ctrl+U]** from the Developer mode boot screen, regardless of the recovery key (meaning they will also work on boards that are typically keyrolled*).
1. Download the shim for your board from [crosbreaker's download site](https://dl.crosbreaker.com/).
2. Flash it to a USB drive, see the [flashing guide](https://docs.crosbreaker.com/quickstart/exploits/misc/flashing-guide/) if you don't know how.
3. Plug in the USB, then do **[Ctrl+U]** to boot from it.

Usually shims are the main way to get code execution, but you can use the shell in MiniOS (when on an eligible device like a nissa, modmium resigns MiniOS on them to enable said shell) if booting the shim somehow fails.

*(\*With devkeys, you are neither keyrolled nor unkeyrolled, since you are using completely different keys)*
## Clearing FWMP
Once you have code execution, open a shell and run the following commands:
```bash
tpm_manager_client take_ownership
cryptohome --action=set_firmware_management_parameters --flags=0 # note, see "Restoring Firmware" if this fails
```
After FWMP is cleared, the Modmium recovery image should work as usual! 

## Restoring Firmware
> [!CAUTION]
> Only use this as a last resort if nothing above works.
>
> If, for some reason, clearing FWMP fails, you can restore your firmware backup and use a normal recovery image. Follow the above steps to gain code execution, then plug in a usb with the firmware backup on it.
1. List all removable devices, usually sh1mmer will be /dev/sda and the other USB will be /dev/sdb
```bash
lsblk | grep sd
```
2. Create your mount directory
```bash
mkdir -p /mnt
```
3. Mount your Firmware backup (Replace sdX with whichever device has the firmware backup)
```bash
mount /dev/sdX /mnt
```
4. Flash it and pray! (This assumes you haven't changed the name of the firmware dump, adjust as necessary)
```bash
flashrom -w /mnt/bios*.fd
```
5. You now either have a paperweight or a usable device, good luck!
