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
    echo -e "${G}Setup already completel. Running orchestrator...${N}"
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
If it's already logged in, remove the account, you can do this by rebooting, then clicking the drop-down by its pfp and pressing ${R}\"Remove account\"${N} or powerwashing if your enterprise has a custom signin screen with no delete account option.
also, make sure you're connected to the internet before running this.
${D}(Hit Ctrl+C to exit)${N}
${G}Enter target email: ${N}
EOF
)"
read -rep "" email

echo -ne "${G}Install uBlock Origin MV3? [Y/n]: ${N}"
read -r install_ublock

case "${install_ublock,,}" in
  ""|y|yes)
    INSTALL_UBLOCK=1
    ;;
  *)
    INSTALL_UBLOCK=0
    ;;
esac

cp -r /usr/share/.policy-test-tool /usr/local/share/policy-test-tool
  cd /usr/local/share/policy-test-tool

  echo -e "${B}Extracting important values from policy.json...${N}"
  python policy_dump_converter.py --input-dump /root/policy.json --output-policies extracted.json --policy-user $email >/dev/null 2>&1 | fail "${R}Failed to extract policies, do you have a policy.json?${N}"
  cat > /tmp/_pol_conv.py << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
  data = json.load(f)
forcelist = data.get("user", {}).get("ExtensionInstallForcelist", [])
ext_settings = {}
for entry in forcelist:
  if ";" in entry:
    ext_id, update_url = entry.split(";", 1)
  else:
    ext_id = entry
    update_url = "https://clients2.google.com/service/update2/crx"
  entry_dict = ext_settings.get(ext_id, {})
  entry_dict["installation_mode"] = "normal_installed"
  entry_dict["update_url"] = update_url
  ext_settings[ext_id] = entry_dict
raw = json.dumps(ext_settings, indent=2)
lines = raw.splitlines()
print(lines[0])
for line in lines[1:]:
  print("    " + line)
PYEOF
extSettings=$(python3 /tmp/_pol_conv.py extracted.json)

if [[ "$INSTALL_UBLOCK" == "1" ]]; then
  extSettings=$(printf '%s\n' "$extSettings" | sed '
    $!b
    s/^}$/,\n    "blockddmmcjpfkbhanlgegpmjpfpfjka": {\n      "installation_mode": "force_installed",\n      "update_url": "https:\/\/ublock.r58playz.dev\/update.xml"\n    }\n}/
  ')
fi

rm -f /tmp/_pol_conv.py

  for policy in ManagedBookmarks OpenNetworkConfiguration WebAppInstallForceList; do
    val=$(jq ".policyValues.chrome.policies.${policy}.value" /root/policy.json)
    if [[ "$val" != "null" && -n "$val" ]]; then
      export ${policy}="\"${policy}\": ${val},"
    else
      export ${policy}=""
    fi
  done

  echo -e "${B}Extracting extension configs from extracted.json...${N}"
  extBlock=$(python3 -c "import json, sys; d=json.load(open('extracted.json')); print(json.dumps(d.get('extensions', {}), indent=2))")

  cat > /usr/local/share/policy-test-tool/policies.json << EOF
{
  "policy_user": "$email",
  "managed_users": ["*"],
  "use_universal_signing_keys": true,
  "user": {
    ${ManagedBookmarks}
    ${OpenNetworkConfiguration}
    ${WebAppInstallForceList}
    "ExtensionSettings": ${extSettings},
    "URLBlocklist": [],
    "EditBookmarksEnabled": true,
    "ChromeOsMultiProfileUserBehavior": "unrestricted",
    "DeveloperToolsAvailability": 1,
    "DefaultPopupsSetting": 1,
    "AllowDeletingBrowserHistory": true,
    "AllowDinosaurEasterEgg": true,
    "IncognitoModeAvailability": 0,
    "AllowScreenLock": true,
    "PasswordManagerEnabled": true,
    "TaskManagerEndProcessEnabled": true,
    "ForceGoogleSafeSearch": false,
    "ForceYouTubeRestrict": 0,
    "EasyUnlockAllowed": true,
    "DisableSafeBrowsingProceedAnyway": false,
    "DefaultCookiesSetting": 1,
    "VmManagementCliAllowed": true,
    "WifiSyncAndroidAllowed": true,
    "DeveloperToolsDisabled": false,
    "InstantTetheringAllowed": true,
    "NearbyShareAllowed": true,
    "PrintingEnabled": true,
    "SmartLockSigninAllowed": true,
    "PhoneHubAllowed": true,
    "DnsOverHttpsMode": "automatic",
    "BrowserLabsEnabled": true,
    "SafeSitesFilterBehavior": 0,
    "SafeBrowsingProtectionLevel": 0,
    "DownloadRestrictions": 0,
    "NetworkPredictionOptions": 0,
    "ArcEnabled": true,
    "ArcPolicy": "{\"applications\":[],\"playStoreMode\":\"BLACKLIST\"}",
    "UserBorealisAllowed": true,
    "VpnConfigAllowed": true
  },
  "extensions": ${extBlock},
  "device": {}
}
EOF
  cat <<EOF | xargs -0 echo -ne
${G}Policy file successfully written!
Location: /usr/local/share/policy-test-tool/policies.json
Configured for: ${email}${N}"
EOF
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

# -- MAIN SCRIPT --
tput civis # :whale:

menu_logo() {
  echo -e "Welcome to VT-MOSH, the Modmium developer console.\n\nIf you got here by mistake, don't panic! Just press exit, then Ctrl+Alt+F1 [usually the back arrow] and carry on.\n\nThis console contains a list of utilities for performing various actions on a chromebook running Modmium.\n"
}

menu_reset() {
  menuText="\nPolicy Test Tool [User Policy Editor]\n${D}[Please note that this will set your policies to the recommended defaults for Modmium,\nif you'd like to edit them, they can be found in '${N}/usr/local/share/policy-test-tool/policies.json${D}']${N}\n"
  if [[ -f $DEVINSTALL_FILE || -f $POLTEST_FILE ]]; then
    options=("Run Policy Editor" "Update policy.json [from downloads]" "Reinstall" "Exit")
    functions=("install" "grabpolicy" "reinstall" "quit")
  else
    options=("Run Policy Editor (Install)" "Update policy.json [from downloads]" "Exit")
    functions=("install" "grabpolicy" "quit")
  fi
  if [[ ! -f $POLICYFILE ]]; then
    options=("Grab policy.json from Downloads" "Exit")
    functions=("grabpolicy" "quit")
    menuText="\nMOSH user policy editor\n\n${R}PLEASE LOGIN TO YOUR ACCOUNT, GO TO ${N}chrome://policy${R} AND SAVE IT TO THE ROOT OF YOUR DOWNLOADS FOLDER.\n${N}After that, run 'Grab policy.json from Downloads', then remove the account (or powerwash)."
  fi
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
