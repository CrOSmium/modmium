for now, this will be a *conceptual* overview of the project.**

** we will be slowly adding features into this, before actually making it, and early parts of this will be developed on top of pre-existing murkmod standards

#### copy-pasted from discussion with dmd and carbon in crosbreaker dev:

### maria:
> people using it should be unenrolled with WP off.
> from there, we can have the readme say to plug in a usb (and have a script ask which usb to back up to, just searching /dev/sd\*), then curl a script which will run make dev ssd and make dev firmware automatically, as well as format the selected usb to vfat then put the firmware backup on it.
> similar to mrchromebox script in that regard.
> it'll also set disable dev request to 1.
> from there readme will say to reboot and enroll in verified mode, plug in the usb, then curl the script again (we can have it check the fw type [normal or developer]) to back up the policy file to the usb
### carbon:
> Is this a image or is it local tho
> I am confuse
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
