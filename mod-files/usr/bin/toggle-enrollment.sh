#!/bin/bash
# written by mariah carey & DMD
# using qs for 142- suggested by xz8f

source /usr/lib/libmosh.sh

mosh_gui_action enrollment.enable yesenroll 2 2 validateGuiEnrollment
mosh_gui_action enrollment.disable noenroll 2 2 validateGuiEnrollment
[[ -f /.deprovision ]] && enrollmentEnabled=false || enrollmentEnabled=true
mosh_gui_state enrollmentEnabled bool "$enrollmentEnabled"
mosh_gui_metadata_done
mosh_gui_state_done

# -- FUNCTIONS --

fail() {
  if [[ "$1" == "" ]]; then
    echo -e "Exiting..."
    sleep 3
    exit 1
  else
    echo -e "$1"
    sleep 0.75
    echo -e "Exiting..."
    sleep 2.25
    exit 1
  fi
}

validateGuiEnrollment() {
  [[ $(mosh_gui_arg 0) == y && $(mosh_gui_arg 1) == y ]]
}

promptPowerwash(){
  echo -e "${Y}Would you like to powerwash now? [y/N]${N}"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "fast safe keepimg" > /mnt/stateful_partition/factory_install_reset
    echo -e "${G}Done! Rebooting...${N}"
    sleep 1
    reboot
  else
    fail # :whale:
  fi
}

allowen(){
  echo -e "${B}You currently have enrollment disabled, would you like to [${G}allow${B}] enrollment? [y/N]${N}"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm /.deprovision
    echo -e "${G}Done!${N}"
    promptPowerwash
  else
    fail # :whale:
  fi
}
  
preventen(){
  echo -e "${B}You currently have enrollment enabled, would you like to [${R}prevent${B}] enrollment? [y/N]${N}"
  read -re
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo $(grep MILESTONE /etc/lsb-release | sed 's|^.*=||g') >/.deprovision
    echo -e "${G}Done!${N}"
    promptPowerwash
  else
    fail # :whale:
  fi
}

noenroll(){
  runscriptnoroot preventen
}

yesenroll(){
  runscriptnoroot allowen
}

# -- MAIN SCRIPT --
tput civis # :whale:


menu_reset() {
  menuText="\nManage Enrollment\n"
  if [[ -f /.deprovision ]]; then
  options=("Enable Enrollment" "Go Back")
  functions=("yesenroll" "quit")
  else
  options=("Disable Enrollment" "Go Back")
  functions=("noenroll" "quit")
  fi
  num_options=${#options[@]}
}

mosh_gui_dispatch
menu_reset
clear
full_menu
tput cnorm
selector
