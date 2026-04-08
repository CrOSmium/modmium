# preventing bricking
Modmium currently does not prevent FWMP from being set, this can mean that if you corrupt chromeOS with FWMP, recovery will be very difficult.

Prevent Bricking (suzyq):
1. Powerwash your chromebook running modmium (you need to be in the OOBE before you enroll)
2. remove FWMP (open vt-2 first)
```
# login as root!
device_managment_client --action=set_firmware_management_parameters --flags=0
```
*we don't remove it with `remove_firmware_management_paramters` because that doesn't always work for some reason*

3. connect your suzyq to your chromebook on both sides
4. Open your GSC
```
gsctool -a -o
```
5. after it reboots and you're on the oobe again, reopen VT-2 and open your suzyq 
```
smiko -c /dev/ttyUSB0
```
6. enter this in the console:
```
> ccd reset factory
> ccd testlab enable
> wp disable
> reboot
```

# how to unbrick
1. flash a SH1mmer image for your board to your USB (if you're already using modmium, i assume you know how to do that)
2. press `esc+reload+power` and `ctrl+d` then `enter`.
3. plug in your SH1mmer USB
4. press `reload+power` to make sure you're in the devmode menu, then quickly press `ctrl+u`
5. once sh1mmer loads, plug your suzyq back into your chromebook like you did prior
6. run these commands to disable wp
```
echo "ccd testlab open" > /dev/ttyUSB0
echo "wp disable" > /dev/ttyUSB0
```

-----------
## MPkeys (or factory fw) Recovery:

1. currently, we do not have a Modmium Recovery Utility that can restore MPkeys if you lost your backup, but this will be that option when it exists (if it does)
2. Use flashrom in SH1mmer (booted in `ctrl+u`) to restore your regular firmware:
```
lsblk # find your fat32 usb with your backed up firmware
mkdir /tmp/usb
mount /dev/sdX /tmp/usb # replace X with whatever letter shows for your USB
cd /tmp/usb
flashrom -w {YOUR FW BACKUP}

# optional stuff:
/usr/share/vboot/bin/set_gbb_flags.sh 0xa0b1 # incase you didn't before and want unenrolling to be easy in the future
```

- also for the other devs im looking into making a Modmium Recovery Utility image, i have a rough idea for what i'll make but i'm not 100% sure it'll work.
