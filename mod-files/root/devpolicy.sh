#!/bin/bash
getSchoolValues() {
	for jqPolicy in DefaultPrinterSelection DeviceLocalAccounts DeviceLoginScreenDomainAutoComplete DeviceLoginScreenLocales DevicePrinters ManagedBookmarks PinnedLauncherApps PrintersBulkConfiguration SystemTimezone WebAppInstallForceList; do
		export Value${jqPolicy}="$(jq .policyValues.chrome.policies.${jqPolicy}.value policy.json)"
	done
	cd .policyedit
	python -m venv .venv
	source .venv/bin/activate
	pip install -r requirements.txt
	export ONC=$(python main.py view --device-policy $(ls -d /var/lib/devicesettings/* | tail -n 1) | grep open_network_configuration: | sed 's/^.*configuration: //')
}

writeJSON() {
cat >poledit.json <<-EOF
{
  "chromePolicies": {
    "AllowDeletingBrowserHistory": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "AllowDinosaurEasterEgg": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "AllowKioskAppControlChromeVersion": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": false
    },
    "AllowScreenLock": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "AllowedDomainsForApps": {
      "error": "Expected string value.",
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "AllowedLanguages": {
      "error": "Expected list value.",
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "AssistantOnboardingMode": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": "Education"
    },
    "AttestationEnabledForDevice": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true 
    },
    "AttestationEnabledForUser": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true 
    },
    "AttestationForContentProtectionEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null 
    },
    "BlockThirdPartyCookies": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "BookmarkBarEnabled": {
      "error": "Expected boolean value.",
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "CACertificateManagementAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 0
    },
    "CaptivePortalAuthenticationIgnoresProxy": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": null 
    },
    "ChromeOsLockOnIdleSuspend": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "ChromeOsMultiProfileUserBehavior": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": "unrestricted"
    },
    "ChromeOsReleaseChannel": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": "testimage-channel"
    },
    "ChromeOsReleaseChannelDelegated": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "ClientCertificateManagementAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 0
    },
    "ClipboardAllowedForUrls": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "ClipboardBlockedForUrls": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "CloudExtensionRequestEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "CloudReportingEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": true
    },
    "CookiesAllowedForUrls": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "CookiesBlockedForUrls": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "CrostiniAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "CrostiniExportImportUIAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "CrostiniPortForwardingAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DefaultClipboardSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultCookiesSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 1
    },
    "DefaultDownloadDirectory": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultGeolocationSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 3
    },
    "DefaultImagesSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultInsecureContentSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultJavaScriptJitSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultJavaScriptSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultNotificationsSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultPopupsSetting": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DefaultPrinterSelection": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": $ValueDefaultPrinterSelection
    },
    "DeveloperToolsAvailability": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 1
    },
    "DeviceActivityHeartbeatEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceAllowBluetooth": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceAllowNewUsers": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceAutoUpdateDisabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceBlockDevmode": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "DeviceDataRoamingEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null 
    },
    "DeviceEphemeralUsersEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "DeviceGuestModeEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceLocalAccounts": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": $ValueDeviceLocalAccounts
    },
    "DeviceLoginScreenDomainAutoComplete": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": $ValueDeviceLoginScreenDomainAutoComplete 
    },
    "DeviceLoginScreenGeolocationAccessLevel": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null 
    },
    "DeviceLoginScreenLocales": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": $ValueDeviceLoginScreenLocales
    },
    "DeviceMetricsReportingEnabled": {
      "info": "This policy cannot be set to \"True\" and be mandatory, therefore it was changed to recommended.",
      "level": "recommended",
      "scope": "machine",
      "source": "platform",
      "value": null 
    },
    "DeviceOpenNetworkConfiguration": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": $ONC
    },
    "DevicePowerAdaptiveChargingEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": null 
    },
    "DevicePrinters": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": $ValueDevicePrinters
    },
    "DevicePrintersAccessMode": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 2
    },
    "DeviceReportNetworkEvents": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "DeviceShowUserNamesOnSignin": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "DeviceSystemWideTracingEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true 
    },
    "DeviceTargetVersionPrefix": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": ""
    },
    "DeviceUnaffiliatedCrostiniAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceUpdateHttpDownloadsEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DeviceUpdateScatterFactor": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DeviceUserAllowlist": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": null
    },
    "DeviceWiFiFastTransitionEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "DisableSafeBrowsingProceedAnyway": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": false
    },
    "DnsOverHttpsMode": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": "automatic"
    },
    "DownloadDirectory": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "DownloadRestrictions": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 0
    },
    "DriveDisabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "DriveDisabledOverCellular": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "EasyUnlockAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "EditBookmarksEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "EmojiSuggestionEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true 
    },
    "EnableSyncConsent": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "ExtensionAllowedTypes": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "ExternalStorageDisabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "ExternalStorageReadOnly": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "FastPairEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true 
    },
    "ForceGoogleSafeSearch": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "ForceYouTubeRestrict": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 0
    },
    "HeartbeatEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "HomepageIsNewTabPage": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "HomepageLocation": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "IncognitoModeAvailability": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 0
    },
    "InstantTetheringAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "IsolatedAppsDeveloperModeAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "JavaScriptBlockedForUrls": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": []
    },
    "KioskCRXManifestUpdateURLIgnored": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": null
    },
    "LidCloseAction": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "LogUploadEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true 
    },
    "LoginAuthenticationBehavior": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": 0
    },
    "LoginDisplayPasswordButtonEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true
    },
    "ManagedBookmarks": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": $ValueManagedBookmarks
    },
    "NTLMShareAuthenticationEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "sourceEnterpriseDefault",
      "value": false
    },
    "NTPCustomBackgroundEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "sourceEnterpriseDefault",
      "value": true
    },
    "NearbyShareAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "NetBiosShareDiscoveryEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "sourceEnterpriseDefault",
      "value": true
    },
    "NetworkFileSharesAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "NetworkThrottlingEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": {
        "download_rate_kbits": 0,
        "enabled": false,
        "upload_rate_kbits": 0
      }
    },
    "OpenNetworkConfiguration": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": $ONC
    },
    "OsColorMode": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": "dark"
    },
    "PasswordManagerEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "PaymentMethodQueryEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "PhoneHubAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "PinUnlockAutosubmitEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "PinnedLauncherApps": {
      "error": "Expected list value.",
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": $ValuePinnedLauncherApps
    },
    "PluginVmAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "PopupsAllowedForUrls": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": null
    },
    "PowerManagementIdleSettings": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "PresentationScreenDimDelayScale": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": null
    },
    "PrintersBulkAccessMode": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": 0
    },
    "PrintersBulkConfiguration": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": $ValuePrintersBulkConfiguration
    },
    "PrintingAllowedColorModes": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": "any"
    },
    "ProxySettings": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "QuickUnlockModeAllowlist": {
      "level": "mandatory",
      "scope": "user",
      "source": "sourceEnterpriseDefault",
      "value": ["all"]
    },
    "RebootAfterUpdate": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "RecoveryFactorBehavior": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true 
    },
    "ReportArcStatusEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": false
    },
    "ReportCRDSessions": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": false
    },
    "ReportDeviceActivityTimes": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceAudioStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceAudioStatusCheckingRateMs": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": 900000
    },
    "ReportDeviceBacklightInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceBluetoothInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceBoardStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceBootMode": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "ReportDeviceCpuInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceCrashReportInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceFanInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceGraphicsStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceLoginLogout": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceMemoryInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceNetworkConfiguration": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceNetworkStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceNetworkTelemetryCollectionRateMs": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": 900000
    },
    "ReportDeviceOsUpdateStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDevicePeripherals": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": false
    },
    "ReportDevicePowerStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDevicePrintJobs": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": false
    },
    "ReportDeviceSecurityStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": false
    },
    "ReportDeviceSessionStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceStorageStatus": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceSystemInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceTimezoneInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportDeviceUsers": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": false
    },
    "ReportDeviceVersionInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true 
    },
    "ReportDeviceVpdInfo": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": true
    },
    "ReportUploadFrequency": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": 10800000
    },
    "RestoreOnStartup": {
      "error": "Expected integer value.",
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "RestoreOnStartupURLs": {
      "error": "Expected list value.",
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "SAMLOfflineSigninTimeLimit": {
      "level": "mandatory",
      "scope": "user",
      "source": "cloud",
      "value": 1209600
    },
    "SafeBrowsingProtectionLevel": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "SafeSitesFilterBehavior": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "SecondaryGoogleAccountSigninAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "ShowCastSessionsStartedByOtherDevices": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true 
    },
    "ShowFullUrlsInAddressBar": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "ShowHomeButton": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "ShowLogoutButtonInTray": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true
    },
    "ShowTouchpadScrollScreenEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true
    },
    "SmartLockSigninAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "SmsMessagesAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "SuggestedContentEnabled": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": false
    },
    "SystemFeaturesDisableList": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": []
    },
    "SystemTerminalSshAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "SystemTimezone": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": $ValueSystemTimezone
    },
    "SystemTimezoneAutomaticDetection": {
      "level": "mandatory",
      "scope": "machine",
      "source": "cloud",
      "value": 0
    },
    "TPMFirmwareUpdateSettings": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "TaskManagerEndProcessEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "TrashEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "URLAllowlist": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "URLBlocklist": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null 
    },
    "UptimeLimit": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": null
    },
    "UserAvatarCustomizationSelectorsEnabled": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "UserBorealisAllowed": {
      "level": "mandatory",
      "scope": "user",
      "source": "platform",
      "value": true
    },
    "VmManagementCliAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    },
    "WebAppInstallForceList": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": $ValueWebAppInstallForceList
    },
    "WifiSyncAndroidAllowed": {
      "level": "mandatory",
      "scope": "machine",
      "source": "platform",
      "value": true
    }
  }
}
EOF
}

generateBlobs() {
	python main.py patch --device-policy $(ls -d /var/lib/devicesettings/* | tail -n 1) --public-key owner.key --new-policy policy.1 --policy-json poledit.json
}

backupBlobs() {
	mkdir -p /root/.blob-backups
	for blob in /var/lib/devicesettings/*; do
		if [[ -f $blob && ! -f /root/.blob-backups/school-$blob ]]; then
			mv $blob /root/.blob-backups/school-$(basename $blob)
		fi
	done
}

overwriteBlobs() {
	rm -rf /var/lib/devicesettings/*
	mkdir -p /var/lib/devicesettings
	mv owner.key /var/lib/devicesettings
	mv policy.1 /var/lib/devicesettings
}

getSchoolValues
writeJSON
generateBlobs
backupBlobs
overwriteBlobs
