#!/bin/bash
# written by Lxrd, DMD and mariah carey

# -- Pre TUI init --
stty -echo
source /usr/lib/libmosh.sh
source /etc/profile

# -- policy flags --
DEVINSTALL_FILE="/mnt/stateful_partition/.devinstall_complete"
POLTEST_FILE="/mnt/stateful_partition/.policytesttool_setup"
POLICYFILE="/root/policy.json"

# -- FUNCTIONS --

fail(){
  echo -e "$1"
  sleep 3
  exit 1
}

reinstall(){
  rm -f "$DEVINSTALL_FILE" "$POLTEST_FILE"
  echo -e "${G}Removed .devinstall_complete and .policytesttool_setup markers.${N}"
  sleep 2
  exit
}

install(){
  clear
  stty echo
  if [[ -f $POLTEST_FILE ]]; then
    echo -e "${G}Setup already completed. Running orchestrator...${N}"
    cd /usr/local/share/policy-test-tool
    /usr/bin/.unhang.sh &
    python orchestrator.py policies.json
    echo -e "${G}Done!${N}"
    kill $(ps aux | grep -F '.unhang.sh' | head -n 1 | awk '{print $2}')
    sleep 3
    exit 0
  fi

  if [[ ! -f $DEVINSTALL_FILE ]]; then
    echo -e "${G}Installing required dependencies...${N}"
    printf 'y\n\nn' | dev_install --reinstall || fail "${R}Could not install dependencies. Connect to the internet first.${N}"
    ldconfig
    emerge protobuf-python
    touch $DEVINSTALL_FILE
  fi

  cp /etc/chrome_dev.conf /etc/.chrome_dev.conf

  cleanup(){
    mv /etc/.chrome_dev.conf /etc/chrome_dev.conf
    exit $?
  }
  trap cleanup EXIT

  echo -n "$(cat <<EOF
${G}+##############################################+
| Policy Test Tool                             |
| -------------------------------------------- |
| Allows policy changes above 131              |
+##############################################+
${B}Run this *before* signing into the target email. ${N}
If it's already logged in, remove the account, you can do this by rebooting, then clicking the drop-down by its pfp and pressing ${R}"Remove account"${N} or powerwashing if your enterprise has a custom signin screen with no delete account option.
also, make sure you're connected to the internet before running this.
${D}(Hit Ctrl+C to exit)${N}
${G}Enter target email: ${N}
EOF
)"
  read -rep "" email

  echo -ne "${G}Install uBlock Origin MV3? [Y/n]: ${N}"
  read -r install_ublock

  if [[ $install_ublock =~ ^[Nn]$ ]]; then
    INSTALL_UBLOCK=0
  else
    INSTALL_UBLOCK=1
  fi

  rm -rf /usr/local/share/policy-test-tool
  cp -r /usr/share/.policy-test-tool /usr/local/share/policy-test-tool
  cd /usr/local/share/policy-test-tool

  echo -e "${B}Extracting important values from policy.json...${N}"
  python policy_dump_converter.py --input-dump /root/policy.json --output-policies extracted.json --policy-user "$email" >/dev/null 2>&1 || fail "${R}Failed to extract policies, do you have a policy.json?${N}"

  UBLOCK_FLAG=""
  [[ "$INSTALL_UBLOCK" == "1" ]] && UBLOCK_FLAG="--ublock"

  echo -e "${B}Building policies.json...${N}"
  python build_policies.py \
    --extracted extracted.json \
    --policy-source /root/policy.json \
    --email "$email" \
    $UBLOCK_FLAG \
    --output /usr/local/share/policy-test-tool/policies.json \
    || fail "${R}Failed to build policies.json${N}"

  echo -e "${G}Policy file successfully written!\nLocation: /usr/local/share/policy-test-tool/policies.json\nConfigured for: ${email}${N}"
  echo -e "${G}Emerging chrome-binary-tests to get fake_dmserver...${N}"
  while [[ ! -f /usr/local/libexec/chrome-binary-tests/fake_dmserver ]]; do
    emerge chrome-binary-tests || echo -e "${R}Failed to emerge fake_dmserver, retrying...${N}"
    sleep 1
  done

  cat <<EOF | xargs -0 echo -ne
${G}Running fake_dmserver in 3 seconds...
(Sign in with the target email, then hit Ctrl+C when you're done)${N}
EOF
  sleep 3
  /usr/bin/.unhang.sh &
  python orchestrator.py policies.json
  kill $(ps aux | grep -F '.unhang.sh' | head -n 1 | awk '{print $2}')
  touch ${POLTEST_FILE}
  echo -e "${G}Done!${N}"
  sleep 3
  exit 0
}

grabpolicy(){
  echo -e "Grabbing policy.json..."
  sleep 0.4
  policy=$(find /home/user/*/MyFiles/Downloads/ -name "policies_*" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d" " -f2-)
  [[ -z "$policy" ]] && echo -e "No policy file found, are you sure it's in Downloads?" >&2
  sudo cp -- "$policy" /root/policy.json > /dev/null 2>&1
  sync # someone's policy.json didn't write
  sleep 1
  echo -e "Refreshing menu..."
  sleep 0.5
  menu_reset
  full_menu
}

grabpol2(){
  employ grabpol2f
  menu_reset
  full_menu
}

grabpol2f(){
  echo -e "Grabbing policies..."
  if ! python /usr/share/.policy-test-tool/decode_policy.py; then
    echo -e "${R}Unable to decode policies!${N}"
    sleep 3
  fi
}

# -- MAIN SCRIPT --
tput civis # :whale:

menu_logo() {
  echo -e "Welcome to VT-MOSH, the Modmium developer console.\n\nIf you got here by mistake, don't panic! Just press exit, then Ctrl+Alt+F1 [usually the back arrow] and carry on.\n\nThis console contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
}

menu_reset() {
  menuText="\nPolicy Test Tool [User Policy Editor]\n${D}[Please note that this will set your policies to the recommended defaults for Modmium,\nif you'd like to edit them, they can be found in '${N}/usr/local/share/policy-test-tool/policies.json${D}']${N}\n"
  if [[ -f $DEVINSTALL_FILE || -f $POLTEST_FILE ]]; then
    options=("Run Policy Editor" "Extract policies from current account" "Update policy.json [from downloads]" "Reinstall" "Exit")
    functions=("install" "grabpol2" "grabpolicy" "reinstall" "quit")
  else
    options=("Run Policy Editor (Install)" "Extract policies from current account" "Update policy.json [from downloads]" "Exit")
    functions=("install" "grabpol2" "grabpolicy" "quit")
  fi
  if [[ ! -f $POLICYFILE ]]; then
    options=("Extract policies from current account" "Grab policy.json from Downloads" "Exit")
    functions=("grabpol2" "grabpolicy" "quit")
    menuText="\nMOSH user policy editor\n\n${R}PLEASE LOGIN TO YOUR ACCOUNT, GO TO ${N}chrome://policy${R} AND SAVE IT TO THE ROOT OF YOUR DOWNLOADS FOLDER.\n${N}After that, run 'Grab policy.json from Downloads', then remove the account (or powerwash).\n\n${R}If ${N}chrome://policy${R} is blocked${N} (${D}or you're feeling lazy${N}), (${R}MAKE SURE YOU'RE LOGGED IN${N}) press the 'Extract Policies from current account',\nthen remove the account (or powerwash).\n"
  fi
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
