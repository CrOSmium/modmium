import json
import sys
import argparse

DEFAULTS = {
    "URLBlocklist": [],
    "EditBookmarksEnabled": True,
    "ChromeOsMultiProfileUserBehavior": "unrestricted",
    "DeveloperToolsAvailability": 1,
    "DefaultPopupsSetting": 1,
    "AllowDeletingBrowserHistory": True,
    "AllowDinosaurEasterEgg": True,
    "IncognitoModeAvailability": 0,
    "AllowScreenLock": True,
    "PasswordManagerEnabled": True,
    "TaskManagerEndProcessEnabled": True,
    "ForceGoogleSafeSearch": False,
    "ForceYouTubeRestrict": 0,
    "EasyUnlockAllowed": True,
    "DisableSafeBrowsingProceedAnyway": False,
    "DefaultCookiesSetting": 1,
    "VmManagementCliAllowed": True,
    "WifiSyncAndroidAllowed": True,
    "DeveloperToolsDisabled": False,
    "InstantTetheringAllowed": True,
    "NearbyShareAllowed": True,
    "PrintingEnabled": True,
    "SmartLockSigninAllowed": True,
    "PhoneHubAllowed": True,
    "DnsOverHttpsMode": "automatic",
    "BrowserLabsEnabled": True,
    "SafeSitesFilterBehavior": 0,
    "SafeBrowsingProtectionLevel": 0,
    "DownloadRestrictions": 0,
    "NetworkPredictionOptions": 0,
    "ArcEnabled": True,
    "ArcPolicy": "{\"applications\":[],\"playStoreMode\":\"BLACKLIST\"}",
    "UserBorealisAllowed": True,
    "VpnConfigAllowed": True,
    "CrostiniAllowed": True,
}

PASSTHROUGH_POLICIES = [
    "ManagedBookmarks",
    "OpenNetworkConfiguration",
    "WebAppInstallForceList",
]

def build_ext_settings(forcelist, install_ublock):
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

    if install_ublock:
        ext_settings["blockddmmcjpfkbhanlgegpmjpfpfjka"] = {
            "installation_mode": "normal_installed",
            "update_url": "https://ublock.r58playz.dev/update.xml",
        }

    return ext_settings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extracted", required=True, help="Path to extracted.json")
    parser.add_argument("--policy-source", required=True, help="Path to original policy.json (for passthrough fields)")
    parser.add_argument("--email", required=True, help="Target user email")
    parser.add_argument("--ublock", action="store_true", help="Install uBlock Origin")
    parser.add_argument("--output", required=True, help="Output policies.json path")
    args = parser.parse_args()

    with open(args.extracted, "r", encoding="utf-8") as f:
        extracted = json.load(f)

    with open(args.policy_source, "r", encoding="utf-8") as f:
        policy_source = json.load(f)

    user = dict(DEFAULTS)

    for key in PASSTHROUGH_POLICIES:
        val = (policy_source.get("policyValues", {})
                            .get("chrome", {})
                            .get("policies", {})
                            .get(key, {})
                            .get("value"))
        if val is not None:
            user[key] = val

    forcelist = extracted.get("user", {}).get("ExtensionInstallForcelist", [])
    if isinstance(forcelist, list) and forcelist:
        user["ExtensionInstallForcelist"] = forcelist

    if args.ublock:
        existing = user.get("ExtensionInstallForcelist", [])
        ublock_entry = "blockddmmcjpfkbhanlgegpmjpfpfjka;https://ublock.r58playz.dev/update.xml"
        if ublock_entry not in existing:
            existing.append(ublock_entry)
        user["ExtensionInstallForcelist"] = existing

    user["ExtensionSettings"] = build_ext_settings(
        user.get("ExtensionInstallForcelist", []),
        args.ublock,
    )

    result = {
        "policy_user": args.email,
        "managed_users": ["*"],
        "use_universal_signing_keys": True,
        "user": user,
        "extensions": extracted.get("extensions", {}),
        "device": {},
    }

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)

    print(f"policies.json written to {args.output}")

if __name__ == "__main__":
    main()
