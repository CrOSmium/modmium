If you would like to contribute, we accept PR's! **Please don't open PR's into the stable branch**, everything new goes through nightly first.

## repo layout
* `bootsplash/`
   * contains default bootsplash SVG files which can be converted into PNG files to be used by modify-bootsplash.sh in MOSH.
* `build-utils/`
   * contains scripts, libraries, and signing keys used for building the image
* `mod-files/`
   * is a rootfs overlay (for example, `mod-files/usr/bin/crosh` is MOSH (MOdmium SHell)
   * `build_image.sh` already handles moving replaced files to `$oldFile.old`, so you don't have to worry about overwriting things in case they need to be called by the modfile (for example `mod-files/sbin/chromeos_startup` needs to call the normal chromeos\_startup, which is at `/sbin/chromeos_startup.old`)
* `build-image.sh`
   * builder for installing modmium to recovery images.
* `docs/`
   * documentation for the various components of modmium, and how to use them.
* `modmium.sh`
   * the devfw installation helper and vt2 installer.
