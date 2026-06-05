## Build instructions
```sh
git clone https://github.com/CrOSmium/modmium && cd modmium 
# if you want to download an image and autobuild
./build_image.sh -b <board> -v <version> <flags>
# if you want to use a local image (non-destructive)
./build_image.sh -i /path/to/image.bin <flags>
```
The builder also has a few other flags, which can be seen by running the script with no arguments or passing `--help`, some of which are listed here.
* `-k`, `--kernver` (hex int, 0 to ff)
    * Can be used to override the kernver of the image. If not set, will use the kernver already present. Useful if you are on a higher kernver than the version you wish to install.
* `-u`, `--userkeys` (bool)
    * Generates new, random keys instead of the standard developer keys. **DO NOT LOSE THEM**, when created they are in build-utils/keys/userkeys/
* `-j`, `--json` (string)
    * The path to your chrome://policy exported JSON file, required to install your school's extensions, user OpenNetworkConfiguration (not DeviceOpenNetworkConfiguration), etc..
If you wish to make any custom modifications (for example adding your github ssh key to /root if you're a developer), add/modify files in mod-files before building.
