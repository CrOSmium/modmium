## The problem
If you enroll while using Modmium and at some point your install gets corrupted to the point where it's unable to boot, recovering with Modmium image is no longer possible because FWMP will prevent booting a developer image. Thankfully, it is fairly trivial to clear FWMP as long as you have code execution.
## Getting code execution.
Thanks to the GBB flags set by `modmium.sh`, shims can be booted with **[Ctrl+U]** on the developer mode boot screen, regardless of the recovery key (meaning they will also work on boards that are typically keyrolled*).
* Download the shim for your board from [crosbreaker's DL site](https://dl.crosbreaker.com/).
* Flash it to a usb, see the [flashing guide](https://docs.crosbreaker.com/quickstart/exploits/misc/flashing-guide/) if you don't know how.
* Plug in the usb, then **[Ctrl+U]** boot it.

*(\*With devkeys, you are neither keyrolled nor unkeyrolled, since you are using completely different keys)*
## Clearing FWMP
Once you have code execution, open a shell and run the following commands:
```bash
tpm_manager_client take_ownership
cryptohome --action=set_firmware_management_parameters --flags=0 # note, see "Restoring Firmware" if this fails
```
After FWMP is cleared, the modmium recovery image should work as usual! 

## Restoring Firmware
> [!CAUTION]
> Only do this if you have no other option.
If, for some reason, clearing FWMP fails, you can restore your firmware backup and use a normal recovery image. Follow the above steps to gain code execution, then plug in a usb with the firmware backup on it.
```bash
lsblk | grep sd # will list all removable devices, usually sh1mmer will be /dev/sda and the other usb will be /dev/sdb
mkdir -p /mnt
mount /dev/sdX /mnt # replace sdX with whichever device has the firmware backup
flashrom -w /mnt/bios*.fd # this assumes you haven't changed the name of the firmware dump, adjust as necessary
```
