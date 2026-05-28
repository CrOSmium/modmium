<img src="https://www.modmium.dev/modmiumoutline2.png" alt="Modmium" width="700">

*Created by [CrOSmium](https://crosmium.dev) and [crosbreaker](https://crosbreaker.com)*

Modmium is a chromeOS modification built to allow the freedom of an unrestricted device on a managed device.

## Features
* Reports as verified in the Google Admin Console (GAC)
* Allows modification of all policies 
* Convenient git updater
* ChromeOS version changer
* Different branches
  * Nightly: where new features are pushed and available for public testing
  * Stable: where changes are pushed after a public beta
* Custom bootsplashes for those who wish to install them
  * Thanks to Casper1051, Moonstone, and pilgorr for creating the default ones :D
* Nix installer for developers to easily install packages (You can use `mix` for APT-like syntax!)

## Getting started
* To build modmium, see [docs/building.md](docs/building.md)
  * Note, see [docs/dependencies.md](docs/dependencies.md) before building to ensure you have the necessary dependencies
  * Feel free to submit a PR adding the dependency list for other distros!
* To install modmium, see [docs/installation.md](docs/installation.md)
* To learn other usage instructions (policy editors, MOSH, etc..), see [docs/usage.md](docs/usage.md)

# Support
If you need any kind of support, please join the [crosbreaker discord server](https://discord.crosbreaker.com) for help.

------------

"*For the love of everything don't use this to cheat. I personally made this out of a passion for learning and programming (it's by far been the most difficult, fun, and largest project I've worked on). 
Your minds are incredible things, don't let them go to waste please.*" - Mariah Scary


## repo layout [to be moved to docs (contributing.md or something)]
(thank you mariah!)
* `bootsplash/`
   * contains default bootsplash SVG files which can be converted into PNG files to be used by modify-bootsplash.sh in MOSH.
* `build-utils/`
   * contains scripts, libraries, and signing keys used for building the image
* `mod-files/`
   * is a rootfs overlay (for example, `mod-files/usr/bin/crosh` is mosh (modmium shell)
   * `build_image.sh` already handles moving replaced files to `$oldFile.old`, so you don't have to worry about overwriting things in case they need to be called by the modfile (for example `mod-files/sbin/chromeos_startup` needs to call the normal chromeos\_startup, which is at `/sbin/chromeos_startup.old`)
* `build-image.sh`
   * builder for installing modmium to recovery images.
* `docs/`
   * documentation for the various components of modmium, and how to use them.
* `modmium.sh`
   * the devfw installation helper (will be hosted on crosbreaker cdn).
