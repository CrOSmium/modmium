#!/bin/bash

# written by lxrd and mariah carey

# colors!
B='\033[1;36m' 
G='\033[1;32m' 
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'    
D='\033[1;90m'

# Root check
if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root. You can do so by using 'sudo su'."
    exit 1
fi

if [[ ! -d /usr/local/share/policy-test-tool ]]; then
	nohup dev_install --reinstall --yes >.devinstall-log 2>&1 & 
	echo -e "${G}(Running dev_install in the background, you may notice your chromebook getting warm...)${N}"
fi
echo -e "\
${G}+##############################################+
| Policy Test Tool                             |
| -------------------------------------------- |
| (WIP) Allows policy changes above 131        |
+##############################################+
${R}Warning: This will prevent school-mandated extensions from installing unless you prepared policy.json in mod-files/root (see readme).
THIS WILL NOT WORK IF YOU'VE RUN 'chromeos-setdevpasswd'${G}
${B}Run this *before* signing into the target email. ${N}
If it's already logged in, remove the account, you can do this by rebooting, then clicking the drop-down by its pfp and pressing ${R}\"Remove account\"${N} or powerwashing if your school has a custom signin screen with no delete account option.
also, make sure you're connected to the internet before running this.
${D}(Hit Ctrl+C to exit)${N}"

sleep 3

echo -ne "${G}Enter target email: ${N}"
read -rep "" email

if [[ ! -f /root/policy.json ]]; then
cat > /root/.policy-test-tool/policies.json << EOF
{
  "policy_user": "$email",
  "managed_users": ["*"],
  "use_universal_signing_keys": true,
  "user": {
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
    "DeviceGuestModeEnabled": true,
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
    "UserBorealisAllowed": true
  },
  "device": {}
}
EOF

echo -e "${G}
Policy file successfully written!
Location: /root/.policy-test-tool/policies.json
Configured for: ${email}${N}"
fi

echo -e "${G}Waiting for python dependencies from dev_install...${N}"
pythonGoogleInstalled=
while [[ $pythonGoogleInstalled != "true" ]]; do
	python -m google >.googleStatus 2>&1
	output=$(cat .googleStatus) # reason we have to do this is because python forces itself into stdout even if the output is supposed to be a variable because python is fucking retarded i hate python
	if [[ $output == *"package"* ]]; then
		pythonGoogleInstalled=true
	fi
	sleep 1
done
#cleaning up
rm -rf .googleStatus .devinstall-log

cp -r /root/.policy-test-tool /usr/local/share/policy-test-tool
cd /usr/local/share/policy-test-tool 

if [[ -f /root/policy.json ]]; then
	echo -e "${B}Extracting extension list from policy.json...${N}"
	python policy_dump_converter.py --input-dump /root/policy.json --output-policies extracted.json --policy-user $email >/dev/null 2>&1
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
    if update_url != "https://clients2.google.com/service/update2/crx":
        entry_dict["update_url"] = update_url
    ext_settings[ext_id] = entry_dict
raw = json.dumps(ext_settings, indent=2)
lines = raw.splitlines()
print(lines[0])
for line in lines[1:]:
    print("    " + line)
PYEOF
	extSettings=$(python3 /tmp/_pol_conv.py extracted.json)
	rm -f /tmp/_pol_conv.py
cat > /usr/local/share/policy-test-tool/policies.json << EOF
{
  "policy_user": "$email",
  "managed_users": ["*"],
  "use_universal_signing_keys": true,
  "user": {
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
    "DeviceGuestModeEnabled": true,
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
    "ExtensionSettings": $extSettings
  },
  "device": {}
}
EOF
	echo -e "${G}
Policy file successfully written!
Location: /usr/local/share/policy-test-tool/policies.json
Configured for: ${email}${N}"
fi

echo -e "${G}Emerging chrome-binary-tests to get fake_dmserver...${N}"
emerge chrome-binary-tests


echo -e "${G}Running fake_dmserver in 3 seconds...
(Sign in with the target email now, then hit Ctrl+C when you're done)${N}"
sleep 3
python orchestrator.py policies.json

echo -e "${G}Done!${N}"