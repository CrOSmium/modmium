#!/bin/bash
# written by DMD
center_menu=1
voffset=5
# -- Pre TUI init --
source /usr/lib/libmosh.sh

stty -echo
if [[ -d /usr/local/nix/store ]]; then
  # issues can get caused if a user has a custom shell.
  # before, this code only ran if .bashrc was sourced,
  # but the shell wouldn't open if .bashrc wasn't sourced
  # chicken and egg. we fix it here.
  if ! mountpoint -q /nix; then
    sudo mkdir -p /nix
    sudo mount --bind /usr/local/nix /nix
  fi
  source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  unset LD_LIBRARY_PATH
fi
menu_logo() {
  echo -ne "\033]0;Modules\007"
  cat << 'EOF'
+-----------------------------------------------------------------------------+
|       .       *       .            .      *        .       *          .     |
|     *      .       *       .   *        .       .       *       .   *       |
|   .    *       .       .   *       .       *        .       .       *       |
|      .   M *       .   D   *        .    L  .     *       . S    *        . |
|   *      .    O   *       .   *    U    .      .  E    *        .   *       |
|       .      *       .         *       .      *       .         *       .   |
|   .       *        .       .       *      .       *        .       .       *|
|      *       .       .   *       .          *       .       .   *       .   |
|   .    *       .                .       * .    *      .              .     *|
|     .     *       .       *        .         .     *      .       *       . |
+-----------------------------------------------------------------------------+
-- Modmium Modules --
EOF
  displaymilestone=0
}
# -- FUNCTIONS --

core(){
  echo "core"
  sleep 1
  menu_reset
  full_menu
}

featured(){
  echo "featured"
  sleep 1
  menu_reset
  full_menu
}

remote(){
  echo "remote"
  sleep 1
  menu_reset
  full_menu
}

# -- MAIN SCRIPT --
tput civis # :whale:
menuText="${D}Modules can be used to select and add specific Modmium features outside of the core project. ${N}(${B}${modver}-${branch}${N})\n"
menu_reset() {
  options=("System" "Featured" "Remote" "Exit")
  functions=("core" "featured" "remote" "quit")
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
