#!/bin/bash
# written by lxrd and mariah carey

source /usr/lib/libmosh.sh

# Root check
if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root. You can do so by using 'sudo -i'."
    exit 1
fi

DEVINSTALL_FILE="/mnt/stateful_partition/.devinstall_complete"
POLTEST_FILE="/mnt/stateful_partition/.policytesttool_setup"

cat <<EOF | xargs -0 echo -ne
${G}To reinstall from scratch, run: bash policy.sh --reinstall${N}
echo -e "${G}Edit policies in /usr/local/share/policy-test-tool/policies.json${N}
EOF
DEFINE_boolean reinstall "$FLAGS_FALSE" "Whether or not to reinstall." "r"
FLAGS $@
if [[ "$FLAGS_reinstall" == "$FLAGS_TRUE" ]]; then
    rm -f "$DEVINSTALL_FILE" "$POLTEST_FILE"
    echo -e "${G}Reinstall flag detected, removed .devinstall_complete and .policytesttool_setup markers. Rerun the script to do a full setup.${N}"
    exit 0
fi

if [[ -f "$POLTEST_FILE" ]]; then
    echo -e "${G}Setup already complete. Running orchestrator...${N}"
    cd /usr/local/share/policy-test-tool
		/root/.unhang.sh &
		python orchestrator.py policies.json
		echo -e "${G}Done!${N}"
		kill $(ps aux | grep -F '.unhang.sh' | head -n 1 | awk '{print $2}') # kill .unhang.sh
		exit 0
fi

if [[ ! -f $DEVINSTALL_FILE ]]; then
	nohup dev_install --reinstall --yes >.devinstall-log 2>&1 &
	echo -e "${G}(Running dev_install in the background, you may notice your chromebook getting warm...)${N}"
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
${R}Warning: This will prevent enterprise-mandated extensions from installing unless you prepared policy.json in mod-files/root (see readme).
THIS WILL NOT WORK IF YOU'VE RUN 'chromeos-setdevpasswd'${G}
${B}Run this *before* signing into the target email. ${N}
If it's already logged in, remove the account, you can do this by rebooting, then clicking the drop-down by its pfp and pressing ${R}\"Remove account\"${N} or powerwashing if your enterprise has a custom signin screen with no delete account option.
also, make sure you're connected to the internet before running this.
${D}(Hit Ctrl+C to exit)${N}
${G}Enter target email: ${N}
EOF
)"
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
  "device": {}
}
EOF

  cat <<EOF | xargs -0 echo -ne
${G}Policy file successfully written!
Location: /root/.policy-test-tool/policies.json
Configured for: ${email}${N}
EOF
fi

cat <<EOF | xargs -0 echo -ne
${G}Waiting for python dependencies from dev_install...${D}
(If this takes more than 5 minutes, something went wrong; open another VT and run dev_install --reinstall)${N}
EOF
pythonGoogleInstalled=
while [[ $pythonGoogleInstalled != $FLAGS_TRUE ]]; do
	if [[ $(python -m google 2>&1) == *"package"* ]]; then
		pythonGoogleInstalled="$FLAGS_TRUE"
	fi
	sleep 1
done
#cleaning up
rm -rf .googleStatus .devinstall-log

cp -r /root/.policy-test-tool /usr/local/share/policy-test-tool
cd /usr/local/share/policy-test-tool

if [[ -f /root/policy.json ]]; then
	echo -e "${B}Extracting important values from policy.json...${N}"
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
fi

echo -e "${G}Emerging chrome-binary-tests to get fake_dmserver...${N}"
while [[ ! -f /usr/local/libexec/chrome-binary-tests/fake_dmserver ]]; do
  emerge chrome-binary-tests || echo -e "${R}Failed to emerge fake_dmserver, retrying...${N}"
done

cat <<EOF | xargs -0 echo -ne
${G}Running fake_dmserver in 3 seconds...
(Sign in with the target email now, then hit Ctrl+C when you're done)${N}
EOF
sleep 3
/root/.unhang.sh &
python orchestrator.py policies.json
kill $(ps aux | grep -F '.unhang.sh' | head -n 1 | awk '{print $2}') # kill .unhang.sh
touch "$DEVINSTALL_FILE" "$POLTEST_FILE"
echo -e "${G}Done!${N}"
exit 0
