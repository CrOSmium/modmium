#!/bin/bash
# originally written by xz8f
# partially rewritten by mariah carey for MOSH
# multiframe bootsplash support added by ReznorsRevenge

DEVINSTALL_FILE="/mnt/stateful_partition/.devinstall_complete"
BOOTSPLASH_CONF="/etc/init/boot-splash.conf"

# check for deps required for multiframe splashes
if [[ ! -f $DEVINSTALL_FILE ]] || ( ! command -v ffmpeg &> /dev/null ); then
  source /etc/profile # emerge breaks without this
  echo -e "${B}Installing required dependencies...${N}"
  if [[ ! -f $DEVINSTALL_FILE ]]; then
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    ldconfig
    touch $DEVINSTALL_FILE
  fi
  
  if [[ -f $DEVINSTALL_FILE ]] || ( ! command -v ffmpeg &> /dev/null ); then
    echo -e "${G}Installing ffmpeg...${N}"
    emerge ffmpeg || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
  fi
fi

source /usr/lib/libmosh.sh

fail() {
  echo -e "$1"
  for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0 2>/dev/null); do
    sudo chown -R chronos:chronos "$downloadsDir/bootsplashes" &>/dev/null
  done
  sleep 3
  exit
}
cros_assets="/usr/share/chromeos-assets/images_100_percent"
cros_assets_2="/usr/share/chromeos-assets/images_200_percent"

# gets chosen bootsplash
get_installed_bootsplashes() {
  stty echo
  for downloadsDir in $(find /home/user/*/MyFiles/Downloads -maxdepth 0); do
    mkdir -p ${downloadsDir}/bootsplashes
    cp /bootsplash/* ${downloadsDir}/bootsplashes >/dev/null 2>&1
    chmod 777 ${downloadsDir}/bootsplashes/*
    chown 0:0 ${downloadsDir}/bootsplashes/*
  done
  echo -e "${G}Placed all installed bootsplashes in Downloads/bootsplashes/ for you to preview.${N}
Open the Files app to see them."
  for image in $(find /bootsplash -mindepth 1 -name '*.png' | sort); do
    echo $(basename $image)
  done
  echo -ne "Enter one of the filenames above: "
  read -rep "" bootsplash
  bootsplash=/bootsplash/$bootsplash
  shouldExit=true
  for image in $(find /bootsplash -mindepth 1 -name '*.png' | sort); do
    if [[ "$bootsplash" == "$image" ]]; then
      shouldExit=false
    fi
  done
  stty -echo
}

# checks if image was built with bootsplashes
if [[ ! -d /bootsplash ]]; then
  replace_broken="$FLAGS_TRUE"
fi

move_images() {
  if [[ -z $(find $cros_assets -name '*.old') ]]; then
    for assets in cros_assets cros_assets_2; do
      for splashframe in $(find ${!assets} -mindepth 1 -name 'boot_splash_frame*.png'); do
        mv $splashframe ${splashframe}.old
        if [[ $splashframe == *"00.png" ]]; then
          cp $1 $splashframe
        fi
      done
    done
  else
    for assets in cros_assets cros_assets_2; do
      cp $1 ${!assets}/boot_splash_frame00.png
    done
  fi
}

replace() {
  get_installed_bootsplashes
  if [[ $shouldExit == true ]]; then
    fail "${R}Invalid filename...${N}"
  else
    move_images $bootsplash
    echo -e "${B}Replaced bootsplash!${N}"
  fi
  fail
}

replace_custom() {
  stty echo
  echo -e "${G}Enter the relative path to the custom image (from the root of the Files app).${N}"
  read -rep " > " custom_img_path
  custom_img_path=$(find /home/user/*/MyFiles -maxdepth 0 | head -n 1)/${custom_img_path}
  if [[ -f $custom_img_path ]]; then
    ldconfig
    if [ "$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$custom_img_path")" != "1" ]; then
      replace_multiframe $custom_img_path
    else
      move_images $custom_img_path
    fi
    echo -e "${B}Replaced bootsplash!${N}"
  else
    fail "${R}The image $custom_img_path does not exist! Make sure you have the path right!${N}"
  fi
  fail
  stty -echo
}

# this is called from replace_custom()
replace_multiframe() {
  tempdir=$(mktemp -d)
  cd $tempdir
  framecount="$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$1")"
  echo -e "${G}Enter the milliseconds per frame.${N}"
  read -rep " > " target_framerate
  if [[ ! "$target_framerate" =~ ^[+-]?[0-9]*\.?[0-9]+$ ]]; then
    fail "${R}Input is not a valid number.${N}"
  fi
  echo -e "${G}Processing multiframe bootsplash...${N}"
  ffmpeg -i $1 -start_number 0 boot_splash_frame%02d.png -loglevel quiet >/dev/null 2>&1 || fail "${R}Error splitting images into frames.${N}"
  # back up existing image(s) (stolen from move_images)
  if [[ -z $(find $cros_assets -name '*.old') ]]; then
    for assets in cros_assets cros_assets_2; do
      for splashframe in $(find ${!assets} -mindepth 1 -name 'boot_splash_frame*.png'); do
        mv $splashframe ${splashframe}.old
      done
    done
  fi
  for assets in cros_assets cros_assets_2; do
    cp * ${!assets}/
  done
  cp $BOOTSPLASH_CONF "${BOOTSPLASH_CONF}.bak"
  sed -i -E "s/--frame-interval[[:space:]]+[0-9]+(\.[0-9]+)?/--frame-interval $target_framerate/g" $BOOTSPLASH_CONF
  cd ..
  rm -rf $tempdir
}

restore_conf_backup() {
  if [[ -f "${BOOTSPLASH_CONF}.bak" ]]; then
    mv "${BOOTSPLASH_CONF}.bak" $BOOTSPLASH_CONF
  fi
}

restore() {
  for assets in cros_assets cros_assets_2; do
    for splashframe in $(find ${!assets} -mindepth 1 -name 'boot_splash_frame*.old'); do
      mv ${splashframe} ${splashframe%.*}
    done
  done
  restore_conf_backup
  echo -e "${B}Restored bootsplash!${N}"
  echo -e "${Y}Note: if the bootsplash is missing or it didn't restore, use the \"Download stock bootsplash\" option${N}" # lol just incase something happens ig
  fail
}

download_backup() {
  tempdir=$(mktemp -d)
  cd $tempdir
  echo -e "${G}Downloading stock bootsplash...${N}"
  curl -LO https://dl.xz8f.gay/chromeos_bootsplash.zip
  echo -e "${Y}Unzipping...${N}"
  bsdtar -xf chromeos_bootsplash.zip
  echo -e "${Y}Creating backup...${N}"
  for assets in $cros_assets $cros_assets_2; do
    for splashframe in boot_splash_frame*.png; do
      cp $splashframe ${assets}/${splashframe}.old
    done
  done
  echo -e "${Y}Cleaning up!${N}"
  cd ..
  rm -rf $tempdir chromeos_bootsplash.zip boot_splash_frame*.png
  echo -e "${B}Done! Use the "Restore stock bootsplash" option to restore.${N}"
  fail
}

remove() {
  echo -e "${Y}This will remove the bootsplash ENTIRELY. Use restore to fix it.${N}"
  read -p "Contnue? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${Y}Removing bootsplash...${N}"
    for assets in cros_assets cros_assets_2; do
      for file in $(find ${!assets} -name 'boot_splash_frame*.png'); do
        rm $file
      done
    done
    echo -e "${G}Removed bootsplash!${N}"
  fi
  fail
}

menu_reset(){
  options=("${G}Replace bootsplash with modmium bootsplash${N}" "${G}Replace bootsplash with custom image${N}" "${G}Restore stock bootsplash${N}" "${G}Download stock bootsplash and save to backup${N}" "${G}Remove bootsplash${N}" "Go Back")
  functions=("replace" "replace_custom" "restore" "download_backup" "remove" "quit")
  if [[ $replace_broken == $FLAGS_TRUE ]]; then
    for array in options functions; do
      declare -n target=$array
      target=("${target[@]:1}")
    done
  fi
  menuText=$(cat <<EOF
${P}+##############################################+
| Bootsplash Replacer                          |
| -------------------------------------------- |
| Replaces the stock ChromeOS bootsplash       |
+##############################################+${N}
${D}(Hit Ctrl+C to return to MOSH)${N}
EOF
  )
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
