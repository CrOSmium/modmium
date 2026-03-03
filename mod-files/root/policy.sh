#!/bin/bash

# mostly written by lxrd
# some QOL added by mariah carey

# Root check
if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root. You can do so by using 'sudo su'."
    exit
fi

echo "+##############################################+"
echo "| Policy Test Tool                             |"
echo "| -------------------------------------------- |"
echo "| (WIP) Allows policy changes above 131        |"
echo "+##############################################+"
echo "WARNING. WILL PREVENT SCHOOL-MANDATED EXTENSIONS FROM INSTALLING."
echo "Run this *before* signing into the target email (if it's already logged in, remove the account."
echo "You can do this by rebooting, then clicking the drop-down by its pfp and pressing \"Remove account\"."
echo "Also, make sure you're connected to the internet before running this."
echo "(Hit Ctrl+C to exit)"

sleep 3

read -p "Enter your email: " email

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
    "ArcPolicy": "{\"playStoreMode\":\"ENABLED\",\"playEmmApiInstallDisabled\":false,\"dpsInteractionsDisabled\":false}",
    "UserBorealisAllowed": true
  },
  "device": {}
}
EOF

echo ""
echo "Policy file successfully written!"
echo "Location: /usr/local/share/policy-test-tool/policies.json"
echo "Configured for: $email"

echo "Installing python..."
dev_install --only_bootstrap --yes || dev_install --only_bootstrap --reinstall # in case someone already has stuff there, overwrite instead of dying
echo "Running fake_dmserver..."
pushd /usr/local/share/policy-test-tool
nohup python orchestrator.py policies.json > /dev/null 2>&1 &
echo "Finished! Sign in with the target email (don't reboot until you do)"
popd
