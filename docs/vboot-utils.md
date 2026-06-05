## Why you might compile from source
* Your distro doesn't provide vboot-utils
* Your distro's package is super outdated 
In these cases, you are able to compile it from source (though running tests will fail unless you satisfy all dependencies, this script only really relies on futility and vbutil_kernel, both of which do not interact with chromeos-flashrom or coreboot).
## Building
(Note, this assumes you have the standard toolchain; git, a compiler, etc..)
```bash
git clone https://chromium.googlesource.com/chromiumos/platform/vboot_reference --depth 1 # depth 1 to save time
cd vboot_reference
make all WERROR= # WERROR= is to suppress compiler warnings on newer compilers for stuff that is intentional
sudo make install
sudo cp -r tests/devkeys /usr/share/vboot/devkeys
```
