## I'm unenrolled, why bother with Modmium?
Modmium is a chromeOS modification built to allow the freedom of an unrestricted device on a managed device. However, this doesn't mean you're strictly required to be *enrolled* to use its features.

Modmium gives you the freedom to choose what you want, so you can *choose* to be unenrolled (but you won't get your enterprise's device policies, like kiosk apps), or you can re-enroll *back* into your enterprise **AFTER** installing Modmium.

Using Modmium enrolled is especially useful for:
* People who need their Kiosk apps to remain even whilst being unrestricted.
* People who want to stay visible to their enterprise's monitoring extension.
* People who want fewer personal restrictions but keep their managed account data.

## Are Modmium's features better than being just unenrolled?
It depends on what you want out of your device. Read the [README.md](/README.md) for more info.

## I want to use Modmium unverified (in actual developer mode).
This isn't recommended, but we can't stop you. Enrolling while being unverified can trigger alerts in your enterprise's Google Admin Console (GAC), potentially resulting in your device being locked, flagged, or other actions. 

Realistically, the only time you'd ever do this is on a fully unmanaged device that you need RW_LEGACY or other devmode specific features on.

To force Modmium to allow booting in full developer mode, open a `root` shell and run:
```bash
touch /root/.dontdothis # if you're enrolled, I do not recommend running this.
```
