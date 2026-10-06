import 'chrome://resources/ash/common/cr_elements/cr_button/cr_button.js';
import 'chrome://resources/ash/common/cr_elements/cr_dialog/cr_dialog.js';
import 'chrome://resources/ash/common/cr_elements/cr_drawer/cr_drawer.js';
import 'chrome://resources/ash/common/cr_elements/cr_icon_button/cr_icon_button.js';
import 'chrome://resources/ash/common/cr_elements/cr_icons.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_hidden_style.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_page_host_style.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_shared_style.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_input/cr_input.js';
import 'chrome://resources/ash/common/cr_elements/cr_link_row/cr_link_row.js';
import 'chrome://resources/ash/common/cr_elements/md_select.css.js';
import 'chrome://resources/ash/common/cr_elements/cr_textarea/cr_textarea.js';
import 'chrome://resources/ash/common/cr_elements/cr_toast/cr_toast.js';
import 'chrome://resources/ash/common/cr_elements/cr_toggle/cr_toggle.js';
import 'chrome://resources/ash/common/cr_elements/cr_toolbar/cr_toolbar_search_field.js';
import 'chrome://resources/ash/common/cr_elements/icons.html.js';
import 'chrome://resources/ash/common/cr_elements/cr_shared_vars.css.js';
import 'chrome://resources/ash/common/cr_elements/cros_color_overrides.css.js';
import 'chrome://resources/polymer/v3_0/iron-icon/iron-icon.js';
import 'chrome://resources/polymer/v3_0/iron-iconset-svg/iron-iconset-svg.js';
import 'chrome://resources/polymer/v3_0/iron-dropdown/iron-dropdown.js';
import 'chrome://resources/polymer/v3_0/iron-media-query/iron-media-query.js';
import 'chrome://resources/polymer/v3_0/iron-selector/iron-selector.js';
import 'chrome://resources/polymer/v3_0/paper-tooltip/paper-tooltip.js';
import {ColorChangeUpdater} from 'chrome://resources/cr_components/color_change_listener/colors_css_updater.js';
import {html, PolymerElement} from 'chrome://resources/polymer/v3_0/polymer/polymer_bundled.min.js';

const MENU_ITEMS = [
  {path: 'manager', label: 'Manager', icon: 'modmium:chrome'},
  {path: 'policies', label: 'Policies', icon: 'modmium:auth-key'},
  {path: 'apps', label: 'Apps', icon: 'modmium:apps'},
  {path: 'misc', label: 'Misc', icon: 'modmium:system-preferences'},
];

const POLICY_CATEGORIES = [
  {name: 'Restrictions', keys: `
    DeviceGuestModeEnabled DeviceShowUserNamesOnSignin DeviceAllowNewUsers DeviceBlockDevmode
    DeviceUnaffiliatedCrostiniAllowed PluginVmAllowed DeviceUserAllowlist DeviceUserWhitelist
    DeviceFamilyLinkAccountsAllowed DeviceBorealisAllowed VirtualMachinesAllowed UnaffiliatedArcAllowed
    SupervisedUsersEnabled DeviceAllowRedeemChromeOsRegistrationOffers DeviceRestrictedManagedGuestSessionEnabled DeviceCrostiniArcAdbSideloadingAllowed
    DeviceLoginScreenExtensionManifestV2Availability DeviceExtensionsSystemLogEnabled DeviceEphemeralUsersEnabled DeviceDebugPacketCaptureAllowed
  `.trim().split(/\s+/)},
  {name: 'Reporting', keys: `
    ReportDeviceVersionInfo ReportDeviceActivityTimes ReportDeviceBootMode ReportDeviceNetworkInterfaces
    ReportDeviceUsers ReportDeviceHardwareStatus ReportDeviceSessionStatus ReportDeviceOsUpdateStatus
    ReportDeviceRunningKioskApp ReportDevicePowerStatus ReportDeviceStorageStatus ReportDeviceBoardStatus
    ReportDeviceCpuInfo ReportDeviceGraphicsStatus ReportDeviceCrashReportInfo ReportDeviceTimezoneInfo
    ReportDeviceMemoryInfo ReportDeviceBacklightInfo ReportDeviceBluetoothInfo ReportDeviceFanInfo
    ReportDeviceVpdInfo ReportDeviceSystemInfo ReportDevicePrintJobs ReportDeviceLoginLogout
    ReportDeviceAudioStatus ReportDeviceNetworkConfiguration ReportDeviceNetworkStatus ReportDeviceSecurityStatus
    ReportCRDSessions ReportDevicePeripherals DeviceReportNetworkEvents DeviceReportRuntimeCounters
    ReportUploadFrequency ReportDeviceNetworkTelemetryCollectionRateMs ReportDeviceAudioStatusCheckingRateMs ReportDeviceAppInfo
    ReportDeviceLocation ReportDeviceNetworkTelemetryEventCheckingRateMs ReportDeviceSignalStrengthEventDrivenTelemetry DeviceReportRuntimeCountersCheckingRateMs
    DeviceReportXDREvents EnableDeviceGranularReporting HeartbeatFrequency DeviceActivityHeartbeatCollectionRateMs
    DeviceActivityHeartbeatEnabled HeartbeatEnabled LogUploadEnabled
  `.trim().split(/\s+/)},
  {name: 'Enterprise', keys: `
    DeviceOpenNetworkConfiguration DevicePrinters DevicePrintersAccessMode DeviceLocalAccounts
    AllowKioskAppControlChromeVersion KioskCRXManifestUpdateURLIgnored DeviceLoginScreenDomainAutoComplete DeviceNativePrinters
    DeviceNativePrintersAccessMode DeviceNativePrintersBlacklist DeviceNativePrintersWhitelist DevicePrintersAllowlist
    DevicePrintersBlocklist DevicePrintingClientNameTemplate DeviceExternalPrintServers DeviceExternalPrintServersAllowlist
    DeviceHostnameTemplate DeviceHostnameUserConfigurable RequiredClientCertificateForDevice SystemProxySettings
    DeviceAllowEnterpriseRemoteAccessConnections DeviceWebBasedAttestationAllowedUrls DeviceLoginScreenAutoSelectCertificateForUrls DeviceLoginScreenSecurityKeyPermitAttestation
    DeviceLoginScreenContextAwareAccessSignalsAllowlist DeviceAuthenticationURLAllowlist DeviceAuthenticationURLBlocklist DeviceGpoCacheLifetime
    DeviceKerberosEncryptionTypes DeviceMachinePasswordChangeRate LoginVideoCaptureAllowedUrls DeviceLoginScreenExtensions
    DeviceLoginScreenInputMethods DeviceLoginScreenLocales ManagedGuestSessionPrivacyWarningsEnabled DeviceLocalAccountAutoLoginId
    DeviceLocalAccountAutoLoginDelay DeviceLocalAccountAutoLoginBailoutEnabled DeviceLocalAccountPromptForNetworkWhenOffline
  `.trim().split(/\s+/)},
  {name: 'Misc', keys: `
    DeviceDataRoamingEnabled DeviceMetricsReportingEnabled ChromeOsReleaseChannel ChromeOsReleaseChannelDelegated
    SystemTimezone SystemTimezoneAutomaticDetection SystemUse24HourClock UptimeLimit
    AttestationEnabledForDevice AttestationForContentProtectionEnabled NetworkThrottlingEnabled DeviceEcryptfsMigrationStrategy
    DeviceWiFiFastTransitionEnabled DeviceAutoUpdateDisabled DeviceTargetVersionPrefix DeviceUpdateScatterFactor
    DeviceUpdateAllowedConnectionTypes DeviceUpdateHttpDownloadsEnabled RebootAfterUpdate DeviceRollbackToTargetVersion
    DeviceAutoUpdateTimeRestrictions DeviceWiFiAllowed DeviceAutoUpdateP2PEnabled DeviceUpdateStagingSchedule
    DeviceScheduledUpdateCheck DeviceTargetVersionSelector DeviceReleaseLtsTag DeviceRollbackAllowedMilestones
    DeviceChannelDowngradeBehavior DeviceExtendedAutoUpdateEnabled DeviceQuickFixBuildToken DeviceMinimumVersion
    DeviceMinimumVersionAueMessage MinimumRequiredChromeVersion DeviceScheduledReboot DeviceRebootOnShutdown
    DeviceRebootOnUserSignout DevicePowerwashAllowed DeviceRunAutomaticCleanupOnLogin AutoCleanUpStrategy
    DeviceShowLowDiskSpaceNotification DeviceAllowMGSToStoreDisplayProperties DeviceSecondFactorAuthentication DeviceLoginScreenGeolocationAccessLevel
    DeviceEphemeralNetworkPoliciesEnabled DeviceEncryptedReportingPipelineEnabled DeviceSystemWideTracingEnabled DevicePolicyRefreshRate
    DeviceVariationsRestrictParameter DeviceChromeVariations DeviceUserPolicyLoopbackProcessingMode DeviceKeylockerForStorageEncryptionEnabled
    DevicePciPeripheralDataAccessEnabled DeviceNativeClientForceAllowed DeviceQuirksDownloadEnabled DeviceHardwareVideoDecodingEnabled
    DeviceUserInitiatedFirmwareUpdatesEnabled DeviceUserInitiatedFlexSystemFirmwareUpdatesEnabled DeviceFlexArcPreloadEnabled DeviceFlexHwDataForProductImprovementEnabled
    DeviceArcDataSnapshotHours ChromadToCloudMigrationEnabled DeviceTransferSAMLCookies DeviceAutofillSAMLUsername
    DeviceLoginScreenIsolateOrigins DeviceLoginScreenSitePerProcess DeviceLoginScreenPreferSlowCiphers DeviceLoginScreenPreferSlowKexAlgorithms
    DeviceLoginScreenWebHidAllowDevicesForUrls DeviceLoginScreenWebUsbAllowDevicesForUrls DeviceLoginScreenPowerManagement DeviceWeeklyScheduledSuspend
    DeviceRestrictionSchedule DevicePowerPeakShiftEnabled DevicePowerPeakShiftBatteryThreshold DevicePowerPeakShiftDayConfig
    DeviceAdvancedBatteryChargeModeEnabled DeviceAdvancedBatteryChargeModeDayConfig DeviceBatteryChargeMode DeviceBatteryChargeCustomStartCharging
    DeviceBatteryChargeCustomStopCharging DevicePowerBatteryChargingOptimization DeviceBootOnAcEnabled DeviceUsbPowerShareEnabled
    DeviceChargingSoundsEnabled DeviceLowBatterySoundEnabled DeviceAllowBluetooth DeviceAllowedBluetoothServices
    DeviceBluetoothJustWorksPairingEnabled DeviceWilcoDtcAllowed DeviceWilcoDtcConfiguration DeviceSystemAecEnabled
    DeviceDisplayResolution DisplayRotationDefault DeviceDockMacAddressSource DeviceWallpaperImage
    CastReceiverName DeviceScreensaverLoginScreenEnabled DeviceScreensaverLoginScreenIdleTimeoutSeconds DeviceScreensaverLoginScreenImageDisplayIntervalSeconds
    DeviceScreensaverLoginScreenImages DeviceLoginScreenShowOptionsInSystemTrayMenu DeviceLoginScreenSystemInfoEnforced DeviceDlcPredownloadList
    ExtensionCacheSize DevicePostQuantumKeyAgreementEnabled DeviceHindiInscriptLayoutEnabled DeviceSwitchFunctionKeysBehaviorEnabled
    DeviceExtendedFkeysModifier DeviceI18nShortcutsEnabled DeviceKeyboardBacklightColor DeviceLoginScreenAccessibilityShortcutsEnabled
    DeviceLoginScreenDefaultHighContrastEnabled DeviceLoginScreenDefaultLargeCursorEnabled DeviceLoginScreenDefaultScreenMagnifierType DeviceLoginScreenDefaultSpokenFeedbackEnabled
    DeviceLoginScreenDefaultVirtualKeyboardEnabled DeviceLoginScreenHighContrastEnabled DeviceLoginScreenLargeCursorEnabled DeviceLoginScreenMonoAudioEnabled
    DeviceLoginScreenSpokenFeedbackEnabled DeviceLoginScreenStickyKeysEnabled DeviceLoginScreenAutoclickEnabled DeviceLoginScreenCaretHighlightEnabled
    DeviceLoginScreenCursorHighlightEnabled DeviceLoginScreenDictationEnabled DeviceLoginScreenFaceGazeEnabled DeviceLoginScreenKeyboardFocusHighlightEnabled
    DeviceLoginScreenPrivacyScreenEnabled DeviceLoginScreenSelectToSpeakEnabled DeviceLoginScreenTouchVirtualKeyboardEnabled DeviceLoginScreenVirtualKeyboardEnabled
    DeviceLoginScreenScreenMagnifierType DeviceLoginScreenPrimaryMouseButtonSwitch DeviceLoginScreenPromptOnMultipleMatchingCertificates DeviceShowNumericKeyboardForPassword
    DeviceAuthDataCacheLifetime DeviceAuthenticationFlowAutoReloadInterval PluginVmLicenseKey LoginAuthenticationBehavior
  `.trim().split(/\s+/)},
];

const GUI_PAGE_OVERRIDES = {
  manager: [
    {
      header: 'Modmium',
      rows: [
        {label: 'Current build', sublabel: 'Modmium', detail: 'update'},
        {label: 'ChromeOS version', detail: 'version'},
        {label: 'Shell', detail: 'shell'},
        {label: 'Source repository', detail: 'repository'},
        {label: 'Boot priority', detail: 'boot'},
      ],
    },
    {
      header: 'Device',
      rows: [
        {label: 'Enrollment', detail: 'enrollment'},
        {label: 'Local account', detail: 'account'},
        {label: 'Feature toggles', detail: 'features'},
      ],
    },
  ],
  policies: [{
    header: 'Policies',
    rows: [
      {label: 'Device policies', sublabel: 'Edit and apply the current device policy', detail: 'device-policies'},
    ],
  }],
  apps: [{
    header: 'MOSH apps',
    rows: [
      {label: 'apps.conf', sublabel: 'Commands shown in the MOSH Apps menu', detail: 'apps-config'},
    ],
  }],
  misc: [{
    header: 'Misc',
    rows: [
      {label: 'Bootsplash', detail: 'bootsplash'},
      {label: 'Cr3nroll', detail: 'cr3nroll'},
      {label: 'Emergency revert', detail: 'revert'},
      {label: 'Nix', detail: 'nix'},
      {label: 'Ashland', detail: 'ashland'},
      {label: 'Credits', detail: 'credits'},
    ],
  }],
};

const DETAIL_DATA = {
  update: {
    page: 'manager', title: 'Update Modmium', cards: [{rows: [
      {label: 'Installed version', sublabel: 'Modmium'},
      {label: 'Branch', kind: 'select', options: ['stable', 'nightly'], value: 'nightly', actions: [
        {label: 'Update', primary: true, confirm: true, prompt: 'Update Modmium now?',
          message: 'Modmium updated', moshAction: 'update.run'},
      ]},
    ]}],
  },
  version: {
    page: 'manager', title: 'ChromeOS version', cards: [{rows: [
      {label: 'Milestone', kind: 'select', options: [], value: '152', actions: [
        {label: 'Install', danger: true, prompt: 'Install this ChromeOS version?',
          message: 'ChromeOS version installed', moshAction: 'version.install'},
      ]},
    ]}],
  },
  shell: {
    page: 'manager', title: 'Shell', cards: [{rows: [
      {label: 'Shell executable', kind: 'input', value: 'bash', actions: [
        {label: 'Save', primary: true, message: 'Shell saved', moshAction: 'shell.set'},
      ]},
    ]}],
  },
  repository: {
    page: 'manager', title: 'Source repository', cards: [{rows: [
      {label: 'Repository URL', kind: 'input', value: 'https://github.com/CrOSmium/modmium', actions: [
        {label: 'Save', primary: true, confirm: true, prompt: 'Use this update repository?',
          message: 'Repository saved', moshAction: 'repository.set', args: ['true']},
      ]},
      {label: 'Official repository', actions: [
        {label: 'Reset', danger: true, prompt: 'Reset to the official Modmium repository?',
          message: 'Repository reset', moshAction: 'repository.reset', args: ['true']},
      ]},
    ]}],
  },
  boot: {
    page: 'manager', title: 'Boot priority', cards: [{rows: [
      {label: 'Current boot root', sublabel: 'Unknown', actions: [
        {label: 'Swap and reboot', danger: true, prompt: 'Switch boot roots and reboot?',
          message: 'Boot priority changed', moshAction: 'boot.swap', args: ['y', 'n', 'n']},
      ]},
    ]}],
  },
  enrollment: {
    page: 'manager', title: 'Enrollment', cards: [{rows: [
      {label: 'Enrollment', sublabel: 'Enabled', actions: [
        {label: 'Disable enrollment', danger: true,
          prompt: 'Change enrollment and powerwash this Chromebook?',
          message: 'Enrollment changed', moshAction: 'enrollment.disable', args: ['y', 'y']},
      ]},
    ]}],
  },
  account: {
    page: 'manager', title: 'Add local account', cards: [{rows: [
      {name: 'username', label: 'Username', kind: 'input'},
      {name: 'domain', label: 'Domain', kind: 'input', value: 'modmium.dev'},
      {name: 'displayName', label: 'Display name', kind: 'input'},
      {name: 'password', label: 'Password', kind: 'password'},
      {name: 'passwordConfirm', label: 'Confirm password', kind: 'password'},
      {actions: [
        {label: 'Create account', primary: true, confirm: true,
          prompt: 'Create this local account and restart Chrome?',
          message: 'Local account created', moshAction: 'account.create',
          fields: ['username', 'domain', 'password', 'passwordConfirm', 'displayName']},
      ]},
    ]}],
  },
  features: {
    page: 'manager', title: 'Feature toggles', cards: [{rows: [
      {label: 'Chromebook Plus features', kind: 'toggle',
        toggleAction: {message: 'Chromebook Plus features changed', moshAction: 'feature.chromebook-plus'}},
      {label: 'Studio Mic', kind: 'toggle',
        toggleAction: {message: 'Studio Mic changed', moshAction: 'feature.studio-mic'}},
      {label: 'System Blur', kind: 'toggle',
        toggleAction: {message: 'System Blur changed', moshAction: 'feature.system-blur'}},
    ]}],
  },
  'device-policies': {
    page: 'policies', title: 'Device policies', cards: [],
  },
  'apps-config': {
    page: 'apps', title: 'Apps', cards: [{header: 'apps.conf', rows: [
      {label: 'Entries', sublabel: 'COMMAND | NAME · Maximum 38 entries',
        kind: 'textarea', value: '', actions: [
          {label: 'Save', primary: true, message: 'Apps configuration saved', moshAction: 'apps.save'},
        ]},
    ]}],
  },
  bootsplash: {
    page: 'misc', title: 'Bootsplash', cards: [{rows: [
      {label: 'Modmium image', kind: 'select', options: [], value: '', actions: [
        {label: 'Replace', primary: true, message: 'Bootsplash replaced', moshAction: 'bootsplash.replace'},
      ]},
      {label: 'Custom image path', kind: 'input', value: 'Downloads/', actions: [
        {label: 'Replace', primary: true, message: 'Bootsplash replaced', moshAction: 'bootsplash.custom'},
      ]},
      {label: 'Stock bootsplash', actions: [
        {label: 'Restore', message: 'Stock bootsplash restored', moshAction: 'bootsplash.restore'},
        {label: 'Download backup', message: 'Stock bootsplash downloaded', moshAction: 'bootsplash.download'},
      ]},
      {label: 'Installed bootsplash', actions: [
        {label: 'Remove', danger: true, prompt: 'Remove the installed bootsplash?',
          message: 'Bootsplash removed', moshAction: 'bootsplash.remove', args: ['y']},
      ]},
    ]}],
  },
  cr3nroll: {
    page: 'misc', title: 'Cr3nroll', cards: [{rows: [
      {label: 'Save current keys as', kind: 'input', actions: [
        {label: 'Save', primary: true, message: 'Enrollment keys saved',
          moshAction: 'cr3nroll.save', appendArgs: ['y']},
      ]},
      {label: 'Saved keys', kind: 'select', options: [], value: '', actions: [
        {label: 'Load', danger: true, prompt: 'Replace the active enrollment keys?',
          message: 'Enrollment keys loaded', moshAction: 'cr3nroll.load'},
      ]},
      {label: 'Generate keys as', kind: 'input', actions: [
        {label: 'Generate', primary: true, message: 'Enrollment keys generated',
          moshAction: 'cr3nroll.generate'},
      ]},
      {label: 'Import directory', kind: 'input', value: '/home/user/', actions: [
        {label: 'Import', danger: true, prompt: 'Overwrite VPD from this directory?',
          message: 'Enrollment information imported', moshAction: 'cr3nroll.import'},
      ]},
      {label: 'Backup directory', kind: 'input', value: '/home/user/', actions: [
        {label: 'Backup', primary: true, message: 'Enrollment information backed up',
          moshAction: 'cr3nroll.backup'},
      ]},
    ]}],
  },
  revert: {
    page: 'misc', title: 'Emergency revert', cards: [{rows: [
      {label: 'Factory ChromeOS milestone', kind: 'select', options: [], value: '152', actions: [
        {label: 'Restore OS and MPkeys', danger: true,
          prompt: 'Restore factory ChromeOS and MPkeys?',
          message: 'Factory restore completed', moshAction: 'revert.factory'},
      ]},
      {label: 'ChromeOS milestone', kind: 'select', options: [], value: '152', actions: [
        {label: 'Restore OS', danger: true, prompt: 'Restore factory ChromeOS?',
          message: 'ChromeOS restored', moshAction: 'revert.os'},
      ]},
      {label: 'MPkeys', actions: [
        {label: 'Revert MPkeys', danger: true, prompt: 'Revert MPkeys?',
          message: 'MPkeys reverted', moshAction: 'revert.mpkeys'},
      ]},
    ]}],
  },
  nix: {
    page: 'misc', title: 'Nix', cards: [{rows: [
      {label: 'Nix', actions: [
        {label: 'Install', primary: true, confirm: true, prompt: 'Install Nix?',
          message: 'Nix installed', moshAction: 'nix.install'},
      ]},
      {label: 'Mix', actions: [
        {label: 'Update', message: 'Mix updated', moshAction: 'mix.update'},
      ]},
    ]}],
  },
  ashland: {
    page: 'misc', title: 'Ashland', cards: [{rows: [
      {label: 'Ashland', sublabel: 'Not installed', actions: [
        {label: 'Install', primary: true, message: 'Ashland installed', moshAction: 'ashland.install'},
        {label: 'Update', message: 'Ashland updated', moshAction: 'ashland.update'},
        {label: 'Uninstall', danger: true, prompt: 'Uninstall Ashland?',
          message: 'Ashland uninstalled', moshAction: 'ashland.uninstall'},
      ]},
      {label: 'Run Ashland', kind: 'toggle',
        toggleAction: {message: 'Ashland state changed', moshAction: 'ashland.toggle'}},
      {label: 'Autostart on reboot', kind: 'toggle',
        toggleAction: {message: 'Ashland autostart changed', moshAction: 'ashland.autostart'}},
      {label: 'Layout', actions: [
        {label: 'Next', message: 'Ashland layout changed', moshAction: 'ashland.layout'},
      ]},
      {label: 'Window gaps', actions: [
        {label: 'Next', message: 'Ashland gaps changed', moshAction: 'ashland.gaps'},
      ]},
    ]}],
  },
  credits: {
    page: 'misc', title: 'Credits', cards: [{header: 'Created by CrOSmium.dev and crosbreaker.com', rows: [
      {label: 'Individual Credits:'},
      {label: 'dmd:', sublabel: 'Project lead; made MOSH/libmosh (and its subMOSHes), base devfw & MPkeys manager, mix, chromeos-setdevpasswd, base ChromeOS version switcher, post kxtzownsu code review, and lots of small changes, and continually maintaining the project after official release [06-07-2026].'},
      {label: 'mariahscarycarey:', sublabel: '(Former) Lead developer; made image builder, device policy editor frontend, ChromeOS version switcher, did most bugfixing, some maintaining up until 06-17-2026, and MANY small changes to other code.'},
      {label: 'lxrd:', sublabel: 'Discovered policy-test-tool and created device policy editing script, made a script to let us stream ChromeOS updates, integrated nix into Modmium.'},
      {label: 'codenerd87:', sublabel: 'Wrote code for restoring MPkeys, fixed devfw flashing on geralt, firmware manager'},
      {label: 'kxtzownsu:', sublabel: "Did early code review to make sure we weren't skidding until he stepped down [05-26-2026]."},
      {label: 'xz8f:', sublabel: 'Helped with custom bootsplashes.'},
      {label: 'Casper1051, Moonstone, pilgorr:', sublabel: 'creating the default bootsplashes.'},
      {label: 'pers5124, dinonuget_, spacenerd1235, xmb9:', sublabel: 'private beta testers, found and reported lots of bugs.'},
      {label: '[ Removing this menu from Modmium is not permitted ]'},
    ]}],
  },
};

const SEARCH_ENTRIES = [
  ...MENU_ITEMS.map(item => ({
    label: item.label,
    page: item.path,
    detail: '',
    icon: item.icon,
  })),
  ...Object.entries(DETAIL_DATA).map(([detail, data]) => ({
    label: data.title,
    page: data.page,
    detail,
    icon: MENU_ITEMS.find(item => item.path === data.page).icon,
  })),
];

class ModmiumIconsElement extends PolymerElement {
  static get is() { return 'modmium-icons'; }
  static get template() {
    return html`
      <iron-iconset-svg name="modmium" size="20">
        <svg><defs>
          <g id="chrome" viewBox="0 0 20 20">
            <path d="M17.418 6.25h-7.417c-1.833 0-3.416 1.417-3.666 3.166l-2.75-4.75c1.5-1.833 3.833-3 6.416-3 3.25 0 6.084 1.834 7.417 4.584Z"></path>
            <path d="M6.751 11.833c.667 1.167 1.834 1.917 3.25 1.917.5 0 .917-.084 1.417-.25l-2.75 4.75c-4-.667-7-4.084-7-8.25 0-1.667.5-3.25 1.333-4.583l3.75 6.416Z"></path>
            <path d="M13.751 10c0 .666-.166 1.333-.5 1.833l-3.75 6.5h.5c4.584 0 8.334-3.75 8.334-8.333 0-1-.167-2-.5-2.917h-5.5c.833.667 1.416 1.75 1.416 2.917Z"></path>
            <path d="M12.918 10a2.917 2.917 0 1 1-5.833 0 2.917 2.917 0 0 1 5.833 0Z"></path>
          </g>
          <g id="auth-key">
            <path d="M6.364 5C3.956 5 2 7.018 2 9.5S3.956 14 6.364 14c1.898 0 3.512-1.252 4.11-3H13.5v3h3v-3H18V8h-7.527c-.597-1.747-2.21-3-4.11-3zm0 6c-.8 0-1.455-.675-1.455-1.5S5.563 8 6.363 8c.8 0 1.454.675 1.454 1.5S7.164 11 6.364 11z"></path>
          </g>
          <g id="apps" viewBox="0 0 20 20">
            <path d="M15 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM5 17a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm10 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm-5 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM5 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm5 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm5 5a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM5 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm5 0a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"></path>
          </g>
          <g id="system-preferences" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.519 18h2.96c.59 0 1.087-.422 1.167-.953l.216-1.491.623-.36 1.44.563c.552.21 1.168-.008 1.44-.492l1.487-2.514a1.127 1.127 0 0 0-.296-1.453l-1.215-.93.016-.358-.016-.36 1.215-.929a1.13 1.13 0 0 0 .288-1.468l-1.471-2.483c-.272-.484-.888-.71-1.456-.507l-1.44.562-.631-.36-.216-1.475c-.072-.57-.568-.992-1.16-.992H8.511c-.584 0-1.08.43-1.152.976l-.216 1.492-.623.359-1.448-.57c-.544-.211-1.16.008-1.432.492L2.16 7.74a1.106 1.106 0 0 0 .297 1.469l1.215.929-.016.36.016.358-1.223.93c-.448.343-.568.952-.288 1.468l1.463 2.475c.272.484.888.71 1.448.508l1.44-.563.631.36.216 1.475c.072.57.568.992 1.16.992ZM10 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"></path>
          </g>
        </defs></svg>
      </iron-iconset-svg>
    `;
  }
}
customElements.define(ModmiumIconsElement.is, ModmiumIconsElement);

class SettingsCardElement extends PolymerElement {
  static get is() { return 'settings-card'; }
  static get properties() { return {headerText: String}; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          --settings-card-bg-color: var(--cros-sys-app_base);
          --settings-card-border-radius: 16px;
          display: flex;
          flex-direction: column;
          margin-bottom: 16px;
          outline: none;
          position: relative;
        }
        @media (prefers-color-scheme: dark) {
          :host { --settings-card-bg-color: var(--cros-sys-surface1); }
        }
        #header { margin: 0; padding: 8px; }
        #headerText {
          color: var(--cros-sys-primary);
          font: var(--cros-button-2-font);
          margin: 0;
        }
        #card {
          background-color: var(--settings-card-bg-color);
          border-radius: var(--settings-card-border-radius);
          flex: 1;
          overflow: hidden;
        }
      </style>
      <template is="dom-if" if="[[headerText]]">
        <div id="header"><h2 id="headerText">[[headerText]]</h2></div>
      </template>
      <div id="card"><slot></slot></div>
    `;
  }
}
customElements.define(SettingsCardElement.is, SettingsCardElement);

class ModmiumSettingsRowElement extends PolymerElement {
  static get is() { return 'modmium-settings-row'; }
  static get properties() { return {item: Object}; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides md-select">
        :host { display: block; }
        .settings-box {
          align-items: center;
          border-top: var(--cr-separator-line);
          display: flex;
          min-height: var(--settings-row-min-height);
          padding: 0 var(--cr-section-padding);
        }
        :host(:first-child) .settings-box { border-top: none; }
        .start { flex: 1; min-width: 0; }
        .settings-box-text {
          box-sizing: border-box;
          padding-block: var(--cr-section-vertical-padding);
          padding-inline-end: 20px;
        }
        .label { color: var(--cros-sys-on_surface); }
        .secondary {
          color: var(--cr-secondary-text-color);
          font-weight: 400;
          white-space: pre-wrap;
        }
        .secondary:empty { display: none; }
        .actions { align-items: center; display: flex; gap: 8px; }
        .settings-box > .actions { margin-inline-start: 8px; }
        cr-input {
          --cr-input-background-color: var(--cros-sys-input_field_on_shaded);
          --cr-input-error-display: none;
          --cr-input-width: 280px;
          margin-inline-start: 16px;
        }
        cr-textarea { margin: 12px 0; width: 100%; }
        .textarea {
          align-items: stretch;
          flex-direction: column;
        }
        .textarea .settings-box-text { padding-inline-end: 0; }
        .textarea cr-textarea { box-sizing: border-box; margin: 0 0 12px; }
        .textarea .actions {
          justify-content: flex-end;
          margin-inline-start: 0;
          padding-bottom: 12px;
        }
        select { --md-select-width: 180px; }
        cr-button.danger { color: var(--cros-sys-error); }
        cr-link-row { min-height: var(--settings-row-min-height); }
        @media (max-width: 680px) {
          .input, .password, .select { flex-wrap: wrap; padding-bottom: 12px; }
          .input .start, .password .start, .select .start { flex-basis: 100%; }
          .input cr-input, .password cr-input {
            --cr-input-width: auto;
            flex: 1;
            margin-inline-start: 0;
            min-width: 0;
          }
        }
      </style>

      <template is="dom-if" if="[[_isLink(item)]]">
        <cr-link-row label="[[item.label]]" sub-label="[[item.sublabel]]"
            on-click="_openDetail" role-description="Subpage">
        </cr-link-row>
      </template>

      <template is="dom-if" if="[[!_isLink(item)]]">
        <div class$="settings-box [[_rowClass(item)]]">
          <div class="start settings-box-text">
            <div class="label">[[item.label]]</div>
            <div class="secondary">[[item.sublabel]]</div>
          </div>

          <template is="dom-if" if="[[_isInput(item)]]">
            <cr-input value="{{item.value}}" aria-label$="[[item.label]]"></cr-input>
          </template>
          <template is="dom-if" if="[[_isPassword(item)]]">
            <cr-input type="password" value="{{item.value}}" aria-label$="[[item.label]]"></cr-input>
          </template>
          <template is="dom-if" if="[[_isSelect(item)]]">
            <select class="md-select" aria-label$="[[item.label]]" on-change="_controlChanged">
              <template is="dom-repeat" items="[[item.options]]" as="option">
                <option selected$="[[_selected(option, item.value)]]">[[option]]</option>
              </template>
            </select>
          </template>
          <template is="dom-if" if="[[_isToggle(item)]]">
            <cr-toggle checked="{{item.checked}}" aria-label$="[[item.label]]"
                on-change="_toggleAction"></cr-toggle>
          </template>
          <template is="dom-if" if="[[_isTextarea(item)]]">
            <cr-textarea value="{{item.value}}" aria-label$="[[item.label]]"></cr-textarea>
          </template>
          <template is="dom-if" if="[[item.actions.length]]">
            <div class="actions">
              <template is="dom-repeat" items="[[item.actions]]" as="action">
                <cr-button class$="[[_buttonClass(action)]]" on-click="_runAction">
                  [[action.label]]
                </cr-button>
              </template>
            </div>
          </template>
        </div>
      </template>
    `;
  }
  _isLink(item) { return Boolean(item && item.detail); }
  _isInput(item) { return item?.kind === 'input'; }
  _isPassword(item) { return item?.kind === 'password'; }
  _isSelect(item) { return item?.kind === 'select'; }
  _isToggle(item) { return item?.kind === 'toggle'; }
  _isTextarea(item) { return item?.kind === 'textarea'; }
  _rowClass(item) { return item?.kind || ''; }
  _selected(option, value) { return option === value; }
  _buttonClass(action) {
    return [action.primary ? 'action-button' : '', action.danger ? 'danger' : '']
      .filter(Boolean).join(' ');
  }
  _openDetail() {
    this.dispatchEvent(new CustomEvent('modmium-open-detail', {
      bubbles: true, composed: true, detail: this.item.detail,
    }));
  }
  _controlChanged(event) { this.set('item.value', event.target.value); }
  _toggleAction() {
    if (!this.item.toggleAction) return;
    this.dispatchEvent(new CustomEvent('modmium-action', {
      bubbles: true, composed: true, detail: {...this.item.toggleAction},
    }));
  }
  fieldValue(name) {
    return this.item.name === name ? String(this.item.value || '') : null;
  }
  _runAction(event) {
    const action = {...event.model.action};
    const control = this.shadowRoot.querySelector('cr-input, select, cr-textarea');
    action.args = control ? [control.value, ...(action.appendArgs || action.args || [])] : action.args || [];
    this.dispatchEvent(new CustomEvent('modmium-action', {
      bubbles: true, composed: true, detail: action,
    }));
  }
}
customElements.define(ModmiumSettingsRowElement.is, ModmiumSettingsRowElement);

class ModmiumPolicyRowElement extends PolymerElement {
  static get is() { return 'modmium-policy-row'; }
  static get properties() { return {policy: Object}; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host { display: block; }
        .row {
          align-items: center;
          border-top: var(--cr-separator-line);
          display: flex;
          gap: 16px;
          min-height: var(--settings-row-min-height);
          padding: 0 var(--cr-section-padding);
        }
        .name {
          color: var(--cros-sys-on_surface);
          flex: 1;
          min-width: 0;
          overflow-wrap: anywhere;
          padding-block: var(--cr-section-vertical-padding);
        }
        .category {
          color: var(--cr-secondary-text-color);
          font: var(--cros-body-2-font);
        }
        cr-input {
          --cr-input-background-color: var(--cros-sys-input_field_on_shaded);
          --cr-input-error-display: none;
          --cr-input-width: min(320px, 40vw);
        }
        @media (max-width: 680px) {
          .row { align-items: stretch; flex-direction: column; gap: 0; padding-bottom: 12px; }
          .name { padding-bottom: 4px; width: 100%; }
          cr-input { --cr-input-width: 100%; width: 100%; }
          cr-toggle, cr-button { align-self: flex-end; }
        }
      </style>
      <div class="row">
        <div class="name">
          [[policy.name]]
          <div class="category" hidden$="[[!policy.showCategory]]">[[policy.category]]</div>
        </div>
        <template is="dom-if" if="[[_isBoolean(policy.type)]]">
          <cr-toggle checked="[[policy.value]]" on-change="_toggle"
              aria-label$="[[policy.name]]"></cr-toggle>
        </template>
        <template is="dom-if" if="[[_isString(policy.type)]]">
          <cr-input value="[[policy.value]]" on-input="_input"
              aria-label$="[[policy.name]]"></cr-input>
        </template>
        <template is="dom-if" if="[[_isNumber(policy.type)]]">
          <cr-input type="number" value="[[policy.value]]" on-input="_number"
              aria-label$="[[policy.name]]"></cr-input>
        </template>
        <template is="dom-if" if="[[_isJson(policy.type)]]">
          <cr-button on-click="_edit">[[_jsonLabel(policy.value)]]</cr-button>
        </template>
      </div>
    `;
  }
  _isBoolean(type) { return type === 'boolean'; }
  _isString(type) { return type === 'string'; }
  _isNumber(type) { return type === 'number'; }
  _isJson(type) { return type === 'json'; }
  _jsonLabel(value) {
    if (value === null || value === undefined) return 'Not set';
    if (Array.isArray(value)) return `${value.length} items`;
    if (typeof value === 'object') return `${Object.keys(value).length} fields`;
    return 'Edit JSON';
  }
  _change(value) {
    this.dispatchEvent(new CustomEvent('modmium-policy-change', {
      bubbles: true,
      composed: true,
      detail: {name: this.policy.name, value, storedAsString: this.policy.storedAsString},
    }));
  }
  _toggle(event) { this._change(event.target.checked); }
  _input(event) { this._change(event.target.value); }
  _number(event) {
    const value = Number(event.target.value);
    if (Number.isFinite(value)) this._change(value);
  }
  _edit() {
    this.dispatchEvent(new CustomEvent('modmium-policy-edit-json', {
      bubbles: true, composed: true, detail: this.policy,
    }));
  }
}
customElements.define(ModmiumPolicyRowElement.is, ModmiumPolicyRowElement);

class ModmiumPolicyEditorElement extends PolymerElement {
  static get is() { return 'modmium-policy-editor'; }
  static get properties() {
    return {
      policies: {type: String, observer: '_loadPolicies'},
      categories: {type: Array, value: () => POLICY_CATEGORIES},
      category: {type: String, value: 'Restrictions'},
      rows: {type: Array, value: () => []},
      query: {type: String, value: ''},
      dirty: {type: Boolean, value: false},
      loaded: {type: Boolean, value: false},
      jsonValue: String,
      jsonError: String,
      editingPolicy: Object,
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides md-select">
        :host { display: block; }
        .controls {
          align-items: center;
          display: flex;
          gap: 12px;
          padding: 12px var(--cr-section-padding);
        }
        .controls cr-input {
          --cr-input-background-color: var(--cros-sys-input_field_on_shaded);
          --cr-input-error-display: none;
          flex: 1;
        }
        select { --md-select-width: 180px; }
        .note {
          color: var(--cr-secondary-text-color);
          padding: 12px var(--cr-section-padding);
        }
        .empty {
          align-items: center;
          display: flex;
          flex-direction: column;
          gap: 16px;
          padding: 40px 16px;
        }
        .actions {
          align-items: center;
          border-top: var(--cr-separator-line);
          display: flex;
          gap: 8px;
          justify-content: flex-end;
          min-height: 64px;
          padding: 0 var(--cr-section-padding);
        }
        cr-button.danger { color: var(--cros-sys-error); }
        .json-body { width: min(440px, calc(100vw - 80px)); }
        #jsonEditor { box-sizing: border-box; width: 100%; }
        #jsonError { color: var(--cros-sys-error); padding-top: 8px; }
        #jsonError:empty { display: none; }
        @media (max-width: 680px) {
          .controls { align-items: stretch; flex-direction: column; }
          select { --md-select-width: 100%; width: 100%; }
          .actions { flex-wrap: wrap; padding-block: 8px; }
        }
      </style>

      <settings-card>
        <template is="dom-if" if="[[!loaded]]">
          <div class="empty">
            <div>No device policy has been loaded.</div>
            <cr-button class="action-button" on-click="_load">Load policies</cr-button>
          </div>
        </template>
        <template is="dom-if" if="[[loaded]]">
          <div class="controls">
            <select class="md-select" aria-label="Policy category" on-change="_categoryChanged">
              <template is="dom-repeat" items="[[categories]]" as="item">
                <option value$="[[item.name]]"
                    selected$="[[_selectedCategory(item.name, category)]]">
                  [[item.name]] ([[item.keys.length]])
                </option>
              </template>
            </select>
            <cr-input placeholder="Search policies" aria-label="Search policies"
                on-input="_search"></cr-input>
          </div>
          <div class="note" hidden$="[[_hideReportingNote(category, query)]]">
            Changing device policies stops reporting to the Google Admin Console.
            Changes to reporting policies have no effect after that.
          </div>
          <template is="dom-repeat" items="[[rows]]" as="policy">
            <modmium-policy-row policy="[[policy]]"
                on-modmium-policy-change="_policyChanged"
                on-modmium-policy-edit-json="_editJson">
            </modmium-policy-row>
          </template>
          <div class="note" hidden$="[[rows.length]]">No matching policies.</div>
          <div class="actions">
            <cr-button disabled$="[[!dirty]]" on-click="_discard">Discard edits</cr-button>
            <cr-button class="danger" on-click="_reset">Reset all changes</cr-button>
            <cr-button class="action-button" on-click="_apply">Apply policies</cr-button>
          </div>
        </template>
      </settings-card>

      <cr-dialog id="jsonDialog">
        <div slot="title">[[editingPolicy.name]]</div>
        <div class="json-body" slot="body">
          <cr-textarea id="jsonEditor" value="{{jsonValue}}" aria-label="JSON value"></cr-textarea>
          <div id="jsonError">[[jsonError]]</div>
        </div>
        <div slot="button-container">
          <cr-button class="cancel-button" on-click="_cancelJson">Cancel</cr-button>
          <cr-button class="action-button" on-click="_saveJson">Save</cr-button>
        </div>
      </cr-dialog>
    `;
  }
  _loadPolicies(policies) {
    try {
      const parsed = JSON.parse(policies || '');
      if (!parsed.device || typeof parsed.device !== 'object' || Array.isArray(parsed.device)) {
        throw new Error();
      }
      this.document = parsed;
      this.loaded = true;
      this.dirty = false;
      this._refreshRows();
    } catch {
      this.document = null;
      this.loaded = false;
      this.rows = [];
    }
  }
  _selectedCategory(name, category) { return name === category; }
  _categoryChanged(event) {
    this.category = event.target.value;
    this._refreshRows();
  }
  _search(event) {
    this.query = event.target.value.trim().toLocaleLowerCase();
    this._refreshRows();
  }
  _hideReportingNote(category, query) { return Boolean(query) || category !== 'Reporting'; }
  _refreshRows() {
    if (!this.document) return;
    const selected = this.query ? POLICY_CATEGORIES :
      POLICY_CATEGORIES.filter(item => item.name === this.category);
    this.rows = selected.flatMap(item => item.keys
      .filter(name => !this.query || name.toLocaleLowerCase().includes(this.query))
      .map(name => this._policy(name, item.name, Boolean(this.query))));
  }
  _policy(name, category, showCategory) {
    let value = this.document.device[name];
    let storedAsString = false;
    if (typeof value === 'string' && /^[\[{]/.test(value.trim())) {
      try {
        value = JSON.parse(value);
        storedAsString = true;
      } catch {}
    }
    const type = ['boolean', 'string', 'number'].includes(typeof value) ? typeof value : 'json';
    return {name, category, showCategory, type, value, storedAsString};
  }
  _policyChanged(event) {
    const {name, value, storedAsString} = event.detail;
    this.document.device[name] = storedAsString ? JSON.stringify(value) : value;
    this.dirty = true;
  }
  _editJson(event) {
    this.editingPolicy = event.detail;
    this.jsonValue = JSON.stringify(event.detail.value, null, 2) ?? 'null';
    this.jsonError = '';
    this.$.jsonDialog.showModal();
  }
  _cancelJson() { this.$.jsonDialog.cancel(); }
  _saveJson() {
    try {
      const value = JSON.parse(this.jsonValue);
      this.document.device[this.editingPolicy.name] = this.editingPolicy.storedAsString ?
        JSON.stringify(value) : value;
      this.dirty = true;
      this.jsonError = '';
      this.$.jsonDialog.close();
      this._refreshRows();
    } catch {
      this.jsonError = 'Enter a valid JSON value.';
    }
  }
  _action(detail) {
    this.dispatchEvent(new CustomEvent('modmium-action', {
      bubbles: true, composed: true, detail,
    }));
  }
  _load() {
    this._action({moshAction: 'policies.load', message: 'Policies loaded'});
  }
  _discard() { this._loadPolicies(this.policies); }
  _reset() {
    this._action({
      moshAction: 'policies.reset',
      danger: true,
      prompt: 'Restore the original device policy?',
      message: 'Policies reset',
    });
  }
  _apply() {
    const contents = `${JSON.stringify(this.document, null, 2)}\n`;
    this.dirty = false;
    this._action({
      moshAction: 'policies.save',
      args: [contents],
      confirm: true,
      prompt: 'Apply these device policies?',
      message: 'Policies applied',
      nextAction: {moshAction: 'policies.apply', message: 'Policies applied'},
    });
  }
}
customElements.define(ModmiumPolicyEditorElement.is, ModmiumPolicyEditorElement);

class OsSettingsMenuItemElement extends PolymerElement {
  static get is() { return 'os-settings-menu-item'; }
  static get properties() {
    return {
      path: {type: String, reflectToAttribute: true},
      icon: String,
      label: String,
      sublabel: String,
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          --tap-target-padding: 3px;
          align-items: center;
          background: transparent;
          border: var(--settings-menu-item-border-width) solid transparent;
          border-radius: 16px;
          box-sizing: border-box;
          color: var(--cros-text-color-primary);
          cursor: pointer;
          display: flex;
          flex-direction: row;
          font: var(--cros-button-1-font);
          height: 60px;
          padding-inline: calc(12px - var(--settings-menu-item-border-width));
          text-decoration: none;
          width: var(--settings-menu-item-width);
        }
        #labelWrapper { flex-grow: 1; max-width: 200px; }
        #label, #sublabel { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        #sublabel { color: var(--cros-sys-on_surface_variant); font: var(--cros-body-2-font); }
        iron-icon { margin-inline-end: 12px; pointer-events: none; }
        :host(:not(.iron-selected)) iron-icon { --iron-icon-fill-color: var(--cros-sys-primary); }
        :host(:not(.iron-selected):hover) { background-color: var(--cros-sys-hover_on_subtle) !important; }
        :host-context(.focus-outline-visible):host(:focus) { border-color: var(--cros-focus-ring-color); }
        :host(.iron-selected) { background-color: var(--cros-sys-primary) !important; color: var(--cros-sys-on_primary); }
        :host(.iron-selected) iron-icon { --iron-icon-fill-color: var(--cros-sys-on_primary); }
        :host(.iron-selected) #sublabel { color: var(--cros-sys-surface_variant); }
      </style>
      <iron-icon icon="[[icon]]"></iron-icon>
      <div id="labelWrapper">
        <div id="label">[[label]]</div>
        <div id="sublabel">[[sublabel]]</div>
      </div>
      <paper-tooltip position="right" offset="4" fit-to-visible-bounds
          animation-delay="1000" aria-hidden="true">[[label]]</paper-tooltip>
    `;
  }
  ready() {
    super.ready();
    this.setAttribute('role', 'link');
    this.setAttribute('tabindex', '0');
    this.addEventListener('keydown', event => {
      if ((event.key === 'Enter' || event.key === ' ') && !event.repeat) {
        event.preventDefault();
        this.click();
      }
    });
  }
}
customElements.define(OsSettingsMenuItemElement.is, OsSettingsMenuItemElement);

class OsSettingsMenuElement extends PolymerElement {
  static get is() { return 'os-settings-menu'; }
  static get properties() { return {items: Array, selectedPath: String}; }
  constructor() {
    super();
    this.items = MENU_ITEMS;
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          box-sizing: border-box;
          display: block;
          padding-bottom: 2px;
          padding-inline-end: var(--settings-menu-padding-inline-end);
          padding-inline-start: var(--settings-menu-padding-inline-start);
          padding-top: var(--settings-menu-padding-top);
          width: var(--settings-menu-width);
        }
        :host * { -webkit-tap-highlight-color: transparent; }
        [selectable] > :focus { background-color: transparent; }
        #topMenu > os-settings-menu-item { margin-bottom: 8px; }
        #topMenu > os-settings-menu-item:last-of-type {
          margin-bottom: calc(48px - calc(var(--tap-target-padding) + var(--settings-menu-item-border-width)));
        }
      </style>
      <iron-selector id="topMenu" role="navigation"
          selectable="os-settings-menu-item" attr-for-selected="path"
          selected="[[selectedPath]]" on-iron-activate="_activate">
        <template is="dom-repeat" items="[[items]]" as="item">
          <os-settings-menu-item path="[[item.path]]" icon="[[item.icon]]"
              label="[[item.label]]" sublabel="[[item.sublabel]]">
          </os-settings-menu-item>
        </template>
      </iron-selector>
    `;
  }
  _activate(event) {
    this.dispatchEvent(new CustomEvent('modmium-navigate', {
      bubbles: true, composed: true, detail: event.detail.item.path,
    }));
  }
}
customElements.define(OsSettingsMenuElement.is, OsSettingsMenuElement);

class OsSearchResultRowElement extends PolymerElement {
  static get is() { return 'os-search-result-row'; }
  static get properties() {
    return {
      result: Object,
      selected: {type: Boolean, reflectToAttribute: true},
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host { display: block; width: 100%; }
        :host([selected]) #searchResultContainer {
          background-color: var(--cros-sys-highlight_shape);
        }
        :host(:not([selected])) #searchResultContainer:hover {
          background-color: var(--cros-sys-hover_on_subtle);
        }
        #searchResultContainer {
          align-items: center;
          color: var(--cros-sys-on_surface);
          cursor: pointer;
          display: flex;
          font: var(--cros-body-2-font);
          height: 48px;
          justify-content: center;
          outline: none;
          width: inherit;
        }
        #resultText { flex-grow: 1; margin: var(--cr-toolbar-search-field-term-margin); }
        iron-icon {
          --iron-icon-fill-color: var(--cros-sys-primary);
          margin: var(--cr-toolbar-icon-margin);
          width: var(--cr-toolbar-icon-container-size);
        }
      </style>
      <div id="searchResultContainer" role="option" on-click="_open">
        <iron-icon icon="[[result.icon]]"></iron-icon>
        <div id="resultText">[[result.label]]</div>
        <iron-icon icon="cr:arrow-forward"></iron-icon>
      </div>
    `;
  }
  _open() {
    this.dispatchEvent(new CustomEvent('modmium-search-select', {
      bubbles: true,
      composed: true,
      detail: this.result,
    }));
  }
}
customElements.define(OsSearchResultRowElement.is, OsSearchResultRowElement);

class OsSettingsSearchBoxElement extends PolymerElement {
  static get is() { return 'os-settings-search-box'; }
  static get properties() {
    return {
      narrow: {type: Boolean, reflectToAttribute: true},
      showingSearch: {type: Boolean, value: false, notify: true, reflectToAttribute: true},
      hasSearchQuery: {type: Boolean, value: false, reflectToAttribute: true},
      query: {type: String, value: ''},
      results: {type: Array, value: () => []},
      selectedResult: {type: Number, value: 0},
      shouldShowDropdown: {type: Boolean, value: false, reflectToAttribute: true},
    };
  }
  static get observers() { return ['_resultsChanged(results.*, query)']; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides">
        :host {
          --cr-toolbar-search-field-background: var(--cros-sys-input_field_on_shaded);
          --cr-toolbar-focused-min-height: 40px;
          --cr-toolbar-icon-container-size: 32px;
          --cr-toolbar-icon-margin: 8px 16px;
          --cr-toolbar-search-field-icon-opacity: 1;
          --cr-toolbar-search-field-narrow-mode-prompt-opacity: 1;
          --cr-toolbar-search-field-prompt-opacity: 1;
          --cr-toolbar-search-icon-margin-inline-start: 16px;
          --cr-toolbar-query-exists-min-height: var(--cr-toolbar-focused-min-height);
          --separator-height: 8px;
          -webkit-tap-highlight-color: transparent;
          display: flex;
          flex-basis: var(--cr-toolbar-field-width);
          transition: width 150ms cubic-bezier(.4, 0, .2, 1);
          width: var(--cr-toolbar-field-width);
        }
        :host([narrow]:not([showing-search])) {
          flex-direction: row;
          justify-content: flex-end;
        }
        :host([narrow][showing-search]) { justify-content: center; }
        cr-toolbar-search-field {
          --cr-toolbar-search-field-term-margin: 0;
          --cr-toolbar-search-field-border-radius: var(--settings-toolbar-search-field-border-radius);
          --cr-toolbar-search-field-paper-spinner-margin: 0 12px;
          --cr-toolbar-search-field-input-icon-color: var(--cros-icon-color-primary);
          --cr-toolbar-search-field-input-text-color: var(--cros-text-color-primary);
          --cr-toolbar-search-field-input-caret-color: currentColor;
          --cr-toolbar-search-field-prompt-color: var(--cros-text-color-secondary);
          --cr-toolbar-icon-button-focus-outline-color: var(--cros-focus-ring-color);
          --cr-toolbar-field-max-width: var(--cr-toolbar-field-width);
          font: var(--cros-body-2-font);
          height: var(--settings-toolbar-search-box-height);
        }
        :host([narrow][showing-search]) cr-toolbar-search-field {
          background-color: var(--cr-toolbar-search-field-background);
        }
        :host([narrow]:not([showing-search])) cr-toolbar-search-field {
          padding-inline-end: var(--settings-toolbar-padding-inline-end);
        }
        :host([showing-search]:focus-within) cr-toolbar-search-field {
          --cr-toolbar-search-field-background: var(--cros-bg-color-elevation-3);
          box-shadow: var(--cr-elevation-1);
          min-height: var(--cr-toolbar-focused-min-height);
        }
        :host([has-search-query]) cr-toolbar-search-field {
          min-height: var(--cr-toolbar-query-exists-min-height);
        }
        :host(:not(:focus-within)) cr-toolbar-search-field {
          --cr-toolbar-search-field-cursor: pointer;
        }
        :host([should-show-dropdown]:focus-within) cr-toolbar-search-field {
          --cr-toolbar-search-field-border-radius: 20px 20px 0 0;
          box-shadow: var(--cr-elevation-3);
          height: 56px;
          margin-top: var(--separator-height);
          padding-bottom: var(--separator-height);
        }
        :host-context([chrome-refresh-2023]) cr-toolbar-search-field { outline-offset: 0; }
        :host-context([chrome-refresh-2023]):host-context(
            html:not(.focus-outline-visible)) cr-toolbar-search-field,
        :host-context([chrome-refresh-2023]):host([showing-search])
            cr-toolbar-search-field { outline: none; }
        iron-dropdown { margin-top: 72px; }
        iron-dropdown [slot='dropdown-content'] {
          background-color: var(--cros-bg-color-elevation-3);
          border-radius: 0 0 20px 20px;
          box-shadow: var(--cr-elevation-3);
          display: table;
          padding-bottom: 8px;
          width: var(--cr-toolbar-field-width);
        }
        #noSearchResultsContainer {
          font: var(--cros-body-2-font);
          height: 32px;
          line-height: 32px;
          margin-inline-start: 24px;
        }
        .separator {
          background-color: var(--cros-bg-color-elevation-3);
          border-top: 1px solid var(--cros-sys-separator);
          height: var(--separator-height);
          margin: -9px 0 0;
        }
      </style>
      <cr-toolbar-search-field id="search" narrow="[[narrow]]"
          label="Search settings" clear-label="Clear search"
          showing-search="{{showingSearch}}" on-search-icon-clicked="_searchIconClicked">
      </cr-toolbar-search-field>
      <iron-dropdown id="searchResults" opened="[[shouldShowDropdown]]"
          allow-outside-scroll no-cancel-on-outside-click>
        <div slot="dropdown-content" role="listbox">
          <div class="separator"></div>
          <template is="dom-repeat" items="[[results]]" as="result" index-as="index">
            <os-search-result-row result="[[result]]"
                selected="[[_isSelected(index, selectedResult)]]">
            </os-search-result-row>
          </template>
          <div id="noSearchResultsContainer" hidden$="[[results.length]]">
            No results found
          </div>
        </div>
      </iron-dropdown>
    `;
  }
  ready() {
    super.ready();
    const input = this.$.search.getSearchInput();
    input.addEventListener('input', () => this._setQuery(input.value));
    input.addEventListener('focus', () => {
      this.showingSearch = true;
      this.shouldShowDropdown = Boolean(this.query);
    });
    input.addEventListener('mousedown', () => {
      if (!this.shouldShowDropdown && this.query) requestAnimationFrame(() => input.select());
    });
    this.addEventListener('keydown', event => this._keydown(event));
    this.addEventListener('focusout', event => {
      if (!this.contains(event.relatedTarget)) this.shouldShowDropdown = false;
    });
    this.addEventListener('modmium-search-select', () => this.clear());
  }
  clear() {
    this.$.search.setValue('');
    this._setQuery('');
    this.shouldShowDropdown = false;
    this.showingSearch = false;
  }
  _setQuery(query) {
    this.query = query;
    this.hasSearchQuery = Boolean(query.trim());
    this.selectedResult = 0;
    this.shouldShowDropdown = this.hasSearchQuery && this.$.search.isSearchFocused();
    this.dispatchEvent(new CustomEvent('modmium-search', {
      bubbles: true,
      composed: true,
      detail: query,
    }));
  }
  _resultsChanged() {
    this.selectedResult = 0;
    this.shouldShowDropdown = Boolean(this.query) && this.$?.search?.isSearchFocused();
  }
  _isSelected(index, selected) { return index === selected; }
  _keydown(event) {
    if (!this.shouldShowDropdown || !this.results.length) return;
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const step = event.key === 'ArrowUp' ? -1 : 1;
      this.selectedResult =
          (this.selectedResult + this.results.length + step) % this.results.length;
    } else if (event.key === 'Enter') {
      event.preventDefault();
      this.dispatchEvent(new CustomEvent('modmium-search-select', {
        bubbles: true,
        composed: true,
        detail: this.results[this.selectedResult],
      }));
    } else if (event.key === 'Escape') {
      this.clear();
    }
  }
  _searchIconClicked() {
    this.$.search.getSearchInput().select();
    this.shouldShowDropdown = Boolean(this.query);
  }
}
customElements.define(OsSettingsSearchBoxElement.is, OsSettingsSearchBoxElement);

class SettingsToolbarElement extends PolymerElement {
  static get is() { return 'settings-toolbar'; }
  static get properties() {
    return {
      results: {type: Array, value: () => []},
      query: {type: String, value: ''},
      narrow: {type: Boolean, reflectToAttribute: true},
      showingSearch: {type: Boolean, reflectToAttribute: true},
      isSearchBoxCutoff: {type: Boolean, reflectToAttribute: true},
    };
  }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides cr-icons cr-hidden-style">
        :host {
          align-items: center;
          background-color: var(--settings-base-bg-color);
          color: var(--cros-text-color-secondary);
          display: flex;
          height: var(--settings-toolbar-height);
          min-height: 56px;
          padding-top: var(--settings-toolbar-padding-top);
          z-index: 3;
        }
        h1 {
          color: var(--cros-sys-primary);
          flex: 1;
          font: var(--cros-title-1-font);
          margin-inline-start: 8px;
          padding-inline-end: 12px;
          white-space: nowrap;
        }
        #leftContent { flex: 0 1 0; position: relative; transition: opacity 100ms; }
        #leftSpacer {
          align-items: center;
          box-sizing: border-box;
          display: flex;
          padding-inline-start: var(--settings-toolbar-padding-inline-start);
          width: var(--settings-menu-width);
        }
        #menuButton {
          --cr-icon-button-fill-color: currentColor;
          --cr-icon-button-size: 32px;
          min-width: 32px;
        }
        #centeredContent {
          display: flex;
          flex: 1 1 0;
          flex-basis: var(--settings-main-basis);
          justify-content: center;
        }
        :host([showing-search][is-search-box-cutoff]) os-settings-search-box {
          --cr-toolbar-field-width: min(80vw, var(--settings-toolbar-search-box-width));
          margin-inline-start: 48px;
        }
        :host([narrow]) #leftSpacer {
          padding-inline-start: var(--settings-toolbar-padding-inline-start-narrow);
          width: 20px;
        }
        :host([narrow]) #centeredContent { position: absolute; width: 100%; z-index: -1; }
        :host([narrow]:not([showing-search])) #centeredContent { justify-content: flex-end; }
        :host([narrow][showing-search]) h1 { display: none; }
        :host([showing-search][is-search-box-cutoff][narrow]) os-settings-search-box {
          --cr-toolbar-field-width: min(80vw, var(--settings-toolbar-narrow-search-box-width));
        }
        :host([showing-search][narrow]:not([is-search-box-cutoff])) os-settings-search-box {
          --cr-toolbar-field-width: var(--settings-toolbar-narrow-search-box-width);
        }
        :host(:not([narrow]):not([is-search-box-cutoff])) os-settings-search-box {
          --cr-toolbar-field-width: var(--settings-toolbar-search-box-width);
        }
      </style>
      <iron-media-query query="(max-width: 780px)"
          query-matches="{{isSearchBoxCutoff}}"></iron-media-query>
      <div id="leftContent">
        <div id="leftSpacer">
          <template is="dom-if" if="[[narrow]]">
            <cr-icon-button id="menuButton" class="no-overlap" iron-icon="cr20:menu"
                on-click="_menu" aria-label="Menu" title="Menu"></cr-icon-button>
          </template>
          <h1>Modmium</h1>
        </div>
      </div>
      <div id="centeredContent">
        <os-settings-search-box id="searchBox" narrow="[[narrow]]"
            query="[[query]]" results="[[results]]"
            showing-search="{{showingSearch}}">
        </os-settings-search-box>
      </div>
    `;
  }
  _menu() { this.dispatchEvent(new CustomEvent('modmium-menu', {bubbles: true, composed: true})); }
}
customElements.define(SettingsToolbarElement.is, SettingsToolbarElement);

class ModmiumSettingsMainElement extends PolymerElement {
  static get is() { return 'modmium-settings-main'; }
  static get properties() {
    return {
      page: String,
      detail: String,
      daemonStatus: String,
      moshMenus: Object,
      modmiumState: Object,
      cards: {
        type: Array,
        computed: '_cards(page, detail, daemonStatus, moshMenus, modmiumState)',
      },
      title: {type: String, computed: '_title(detail)'},
    };
  }
  static get observers() { return ['_routeChanged(page, detail)']; }
  static get template() {
    return html`
      <style include="cr-shared-style cros-color-overrides cr-icons">
        :host {
          align-items: center;
          box-sizing: border-box;
          display: flex;
          flex-direction: column;
          padding: 0 16px 16px;
        }
        #mainPageContainer {
          --page-backdrop-bg-color: var(--cros-sys-surface1);
          background-color: var(--page-backdrop-bg-color);
          border-radius: 20px;
          box-sizing: border-box;
          flex: 1;
          max-width: 958px;
          min-height: 100%;
          min-width: 640px;
          padding: 8px 16px 16px;
          position: relative;
          width: 100%;
        }
        #mainPageContainer.entering {
          animation: settings-page-enter 120ms cubic-bezier(.2, 0, 0, 1);
        }
        @keyframes settings-page-enter {
          from { opacity: 0; transform: translateY(4px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-color-scheme: dark) {
          #mainPageContainer { --page-backdrop-bg-color: var(--cros-sys-app_base); }
        }
        #subpageHeader {
          align-items: center;
          display: flex;
          min-height: 40px;
          padding: 16px 0;
        }
        #subpageHeader[hidden] { display: none; }
        #subpageTitle {
          color: var(--cros-sys-primary);
          flex: 1;
          font: var(--cros-button-1-font);
          margin: 0;
        }
        #backButton {
          --cr-icon-button-fill-color: var(--cros-sys-primary);
          margin-inline-end: 10px;
          margin-inline-start: -10px;
        }
        @media (max-width: 680px) {
          #mainPageContainer { min-width: 0; }
          :host { padding-inline: 3px; }
        }
        @media (prefers-reduced-motion: reduce) {
          #mainPageContainer.entering { animation: none; }
        }
      </style>
      <div id="mainPageContainer">
        <div id="subpageHeader" class="cr-row first" hidden$="[[!detail]]">
          <cr-icon-button id="backButton" class="icon-arrow-back"
              iron-icon="cr:arrow-back" on-click="_back"
              aria-label="Back">
          </cr-icon-button>
          <h1 id="subpageTitle">[[title]]</h1>
        </div>
        <template is="dom-if" if="[[_isPolicyEditor(detail)]]">
          <modmium-policy-editor policies="[[modmiumState.devicePolicies]]">
          </modmium-policy-editor>
        </template>
        <template is="dom-if" if="[[_showCards(detail)]]">
          <template is="dom-repeat" items="[[cards]]" as="card">
            <settings-card header-text="[[card.header]]">
              <template is="dom-repeat" items="[[card.rows]]" as="row">
                <modmium-settings-row item="[[row]]"></modmium-settings-row>
              </template>
            </settings-card>
          </template>
        </template>
      </div>
    `;
  }
  _cards(page, detail, daemonStatus, moshMenus, state) {
    const source = detail ? DETAIL_DATA[detail]?.cards :
      GUI_PAGE_OVERRIDES[page] || genericMenuCards(moshMenus?.[page]);
    const cards = structuredClone(source || GUI_PAGE_OVERRIDES.manager);
    for (const card of cards) {
      for (const row of card.rows) {
        if (row.status) row.sublabel = daemonStatus;
        if (row.detail && !row.action) row.action = 'Open';
      }
    }
    this._applyState(cards, page, detail, state);
    return cards;
  }
  _applyState(cards, page, detail, state) {
    if (!state?.repository) return;
    const rows = cards.flatMap(card => card.rows);
    const row = label => rows.find(candidate => candidate.label === label);
    if (!detail && page === 'manager') {
      row('Current build').sublabel = `Modmium ${state.modmiumVersion} ${state.branch}`;
      row('ChromeOS version').sublabel = state.chromeosVersion;
      row('Shell').sublabel = state.shell;
      row('Source repository').sublabel = state.repository.replace('https://github.com/', '');
      row('Enrollment').sublabel = state.enrollmentEnabled ? 'Enabled' : 'Disabled';
    } else if (detail === 'update') {
      row('Installed version').sublabel = `Modmium ${state.modmiumVersion} ${state.branch}`;
      row('Branch').value = state.branch;
    } else if (detail === 'version') {
      row('Milestone').options = state.stableVersions;
      row('Milestone').value = state.chromeosVersion;
    } else if (detail === 'shell') {
      row('Shell executable').value = state.shell;
    } else if (detail === 'repository') {
      row('Repository URL').value = state.repository;
    } else if (detail === 'boot') {
      row('Current boot root').sublabel = state.bootRoot;
    } else if (detail === 'enrollment') {
      const enrollment = row('Enrollment');
      enrollment.sublabel = state.enrollmentEnabled ? 'Enabled' : 'Disabled';
      enrollment.actions[0].label = state.enrollmentEnabled ?
        'Disable enrollment' : 'Enable enrollment';
      enrollment.actions[0].moshAction = state.enrollmentEnabled ?
        'enrollment.disable' : 'enrollment.enable';
    } else if (detail === 'features') {
      row('Chromebook Plus features').checked = state.chromebookPlus;
      row('Studio Mic').checked = state.studioMic;
      row('System Blur').checked = state.systemBlur;
    } else if (detail === 'apps-config') {
      rows.find(candidate => candidate.kind === 'textarea').value = state.appsConfig;
    } else if (detail === 'bootsplash') {
      const installed = row('Modmium image');
      installed.options = state.bootsplashes;
      installed.value = state.bootsplashes[0] || '';
      if (!state.bootsplashes.length) {
        cards[0].rows = cards[0].rows.filter(candidate => candidate !== installed);
      }
    } else if (detail === 'cr3nroll') {
      const saved = row('Saved keys');
      saved.options = state.savedEnrollmentKeys;
      saved.value = state.savedEnrollmentKeys[0] || '';
    } else if (detail === 'revert') {
      row('Factory ChromeOS milestone').options = state.stableVersions;
      row('Factory ChromeOS milestone').value = state.chromeosVersion;
      row('ChromeOS milestone').options = state.stableVersions;
      row('ChromeOS milestone').value = state.chromeosVersion;
    } else if (detail === 'nix') {
      row('Nix').sublabel = state.nixInstalled ? 'Installed' : 'Not installed';
      if (!state.nixInstalled) cards[0].rows = [row('Nix')];
    } else if (detail === 'ashland') {
      const ashland = row('Ashland');
      ashland.sublabel = state.ashlandInstalled ? 'Installed' : 'Not installed';
      ashland.actions = state.ashlandInstalled ? ashland.actions.slice(1) : ashland.actions.slice(0, 1);
      row('Run Ashland').checked = state.ashlandRunning;
      row('Autostart on reboot').checked = state.ashlandAutostart;
      row('Layout').sublabel = state.ashlandLayout;
      row('Window gaps').sublabel = state.ashlandGaps;
      if (!state.ashlandInstalled) cards[0].rows = [ashland];
    }
  }
  _title(detail) { return DETAIL_DATA[detail]?.title || ''; }
  _isPolicyEditor(detail) { return detail === 'device-policies'; }
  _showCards(detail) { return !this._isPolicyEditor(detail); }
  fieldValues(names) {
    const rows = [...this.shadowRoot.querySelectorAll('modmium-settings-row')];
    return names.map(name => {
      for (const row of rows) {
        const value = row.fieldValue(name);
        if (value !== null) return value;
      }
      return '';
    });
  }
  _routeChanged() {
    if (!this.$?.mainPageContainer) return;
    this.$.mainPageContainer.classList.remove('entering');
    requestAnimationFrame(() => this.$.mainPageContainer.classList.add('entering'));
  }
  _back() { this.dispatchEvent(new CustomEvent('modmium-back', {bubbles: true, composed: true})); }
}
customElements.define(ModmiumSettingsMainElement.is, ModmiumSettingsMainElement);

class ModmiumSettingsUiElement extends PolymerElement {
  static get is() { return 'modmium-settings-ui'; }
  static get properties() {
    return {
      page: {type: String, value: 'manager'},
      detail: {type: String, value: ''},
      daemonStatus: {type: String, value: 'Connecting to Modmium'},
      moshMenus: {type: Object, value: () => ({})},
      modmiumState: {type: Object, value: () => ({})},
      isNarrow: {type: Boolean, value: false},
      query: {type: String, value: ''},
      searchResults: {type: Array, value: () => []},
      pendingAction: Object,
      toastText: String,
    };
  }
  static get template() {
    return html`
      <style include="cr-page-host-style cr-shared-style cros-color-overrides cr-icons">
        :host { display: flex; flex-direction: column; height: 100%; }
        :host {
          --settings-main-basis: calc(var(--cr-centered-card-max-width) / .96);
          --cr-card-border-radius: 4px;
          --cr-card-shadow: var(--cr-elevation-1);
          --cr-toolbar-padding-top: 8px;
        }
        #container {
          align-items: flex-start;
          display: flex;
          flex: 1;
          overflow: overlay;
          position: relative;
        }
        #left, #center { flex: 1 1 0; }
        #left {
          flex-grow: 0;
          height: 100%;
          position: sticky;
          top: 0;
          z-index: 100;
        }
        #left os-settings-menu { height: 100%; overflow: auto; overscroll-behavior: contain; }
        #center {
          box-sizing: border-box;
          flex-basis: var(--settings-main-basis);
          height: 100%;
          padding-top: 8px;
        }
        #center > modmium-settings-main { min-height: 100%; }
        #drawer {
          --cr-drawer-border-start-end-radius: 12px;
          --cr-drawer-border-end-end-radius: 12px;
          --cr-drawer-header-color: var(--cros-sys-primary);
          --cr-drawer-header-font: var(--cros-title-1-font);
          --cr-drawer-header-padding: 22px;
          --cr-drawer-width: var(--settings-menu-width);
          --cr-separator-line: none;
        }
        #drawerIcon {
          --iron-icon-fill-color: var(--cros-sys-primary);
          margin-inline-end: 6px;
          margin-inline-start: 0;
        }
        cr-toast { left: 50%; transform: translateX(-50%); }
        @media (max-width: 980px) {
          #left { display: none; }
          #center { min-width: auto; padding: 0 3px; }
        }
      </style>

      <modmium-icons></modmium-icons>
      <iron-media-query query="(max-width: 980px)"
          query-matches="{{isNarrow}}"></iron-media-query>
      <settings-toolbar query="[[query]]" results="[[searchResults]]" narrow="[[isNarrow]]"
          on-modmium-menu="_toggleMenu"
          on-modmium-search="_search"
          on-modmium-search-select="_searchSelect">
      </settings-toolbar>

      <cr-drawer id="drawer" heading="Modmium" align="left">
        <div slot="header-icon">
          <cr-icon-button id="drawerIcon" iron-icon="cr20:menu"
              on-click="_closeMenu" title="Close"></cr-icon-button>
        </div>
        <div slot="body">
          <os-settings-menu selected-path="[[page]]"
              on-modmium-navigate="_navigatePage"></os-settings-menu>
        </div>
      </cr-drawer>

      <div id="container">
        <div id="left">
          <os-settings-menu selected-path="[[page]]" on-modmium-navigate="_navigatePage">
          </os-settings-menu>
        </div>
        <div id="center">
          <modmium-settings-main id="main" page="[[page]]" detail="[[detail]]"
              daemon-status="[[daemonStatus]]"
              mosh-menus="[[moshMenus]]"
              modmium-state="[[modmiumState]]"
              on-modmium-open-detail="_openDetail"
              on-modmium-action="_action"
              on-modmium-back="_back">
          </modmium-settings-main>
        </div>
      </div>

      <cr-toast id="toast" duration="2500"><span>[[toastText]]</span></cr-toast>
      <iframe id="daemonBridge" hidden src="http://127.0.0.1:27182/bridge"
          title="Modmium service"></iframe>
      <cr-dialog id="confirmDialog">
        <div slot="title">Confirm action</div>
        <div slot="body">[[pendingAction.message]]</div>
        <div slot="button-container">
          <cr-button class="cancel-button" on-click="_cancelAction">Cancel</cr-button>
          <cr-button class="action-button" on-click="_confirmAction">Continue</cr-button>
        </div>
      </cr-dialog>
    `;
  }
  connectedCallback() {
    super.connectedCallback();
    window.addEventListener('popstate', () => this._readRoute());
    this._daemonMessage = event => this._handleDaemonMessage(event);
    window.addEventListener('message', this._daemonMessage);
    this._readRoute();
    this._connectDaemon();
    document.documentElement.classList.remove('loading');
  }
  disconnectedCallback() {
    super.disconnectedCallback();
    window.removeEventListener('message', this._daemonMessage);
    clearTimeout(this._daemonTimer);
  }
  _readRoute() {
    const [page = 'manager', detail = ''] = location.hash.replace(/^#\/?/, '').split('/');
    if (DETAIL_DATA[detail]) {
      this.page = DETAIL_DATA[detail].page;
      this.detail = detail;
    } else {
      this.page = (GUI_PAGE_OVERRIDES[page] || this.moshMenus[page]) ? page : 'manager';
      this.detail = '';
    }
  }
  _setRoute(page, detail = '') {
    const hash = `#/${page}${detail ? `/${detail}` : ''}`;
    if (location.hash === hash) return;
    history.pushState({}, '', hash);
    this.page = page;
    this.detail = detail;
    this.query = '';
    this.searchResults = [];
    this.$.container.scrollTo({top: 0, behavior: 'auto'});
  }
  _navigatePage(event) {
    this._setRoute(event.detail);
    if (this.isNarrow) this.$.drawer.close();
  }
  _openDetail(event) { this._setRoute(this.page, event.detail); }
  _back() {
    if (this.detail) history.back();
  }
  _toggleMenu() { this.$.drawer.openDrawer(); }
  _closeMenu() { this.$.drawer.close(); }
  _search(event) {
    this.query = event.detail.trim();
    const query = this.query.toLocaleLowerCase();
    this.searchResults = query ? SEARCH_ENTRIES.filter(entry =>
      entry.label.toLocaleLowerCase().includes(query)).slice(0, 6) : [];
  }
  _searchSelect(event) {
    const entry = event.detail;
    this._setRoute(entry.page, entry.detail);
  }
  _action(event) {
    let action = {...event.detail};
    if (action.fields) action.args = this.$.main.fieldValues(action.fields);
    action = this._prepareAction(action);
    if (action.danger || action.confirm) {
      this.pendingAction = {
        ...action,
        successMessage: action.message,
        message: action.prompt || action.message,
      };
      this.$.confirmDialog.showModal();
      return;
    }
    this._runAction(action);
  }
  _prepareAction(action) {
    const args = action.args || [];
    if (action.moshAction === 'version.install') {
      const target = Number(args[0]);
      const current = Number(this.modmiumState.chromeosVersion);
      action.args = [String(target)];
      if (target < current) action.args.push('y');
      if (target < 131) action.args.push('y');
      action.args.push(this.modmiumState.branch, 'y', 'n', 'n', 'n');
    } else if (action.moshAction === 'cr3nroll.generate') {
      action.args = ['y', 'a', 'y', args[0]];
    } else if (action.moshAction === 'revert.factory') {
      action.args = ['y'];
      if (/^(corsola|dedede|nissa)/.test(this.modmiumState.board)) action.args.push('n');
      action.args.push(args[0]);
    } else if (action.moshAction === 'revert.mpkeys') {
      action.args = ['y'];
      if (/^(corsola|dedede|nissa)/.test(this.modmiumState.board)) action.args.push('n');
    }
    return action;
  }
  _cancelAction() {
    this.$.confirmDialog.cancel();
    this.pendingAction = null;
  }
  _confirmAction() {
    const action = this.pendingAction;
    this.$.confirmDialog.close();
    this.pendingAction = null;
    this._runAction(action);
  }
  _runAction(action) {
    if (!action.moshAction) {
      this._showToast(action.message);
      return;
    }
    const fields = ['run', action.moshAction, ...(action.args || [])]
      .map(field => encodeURIComponent(String(field)));
    this._pendingMoshAction = action;
    this.$.daemonBridge.contentWindow.postMessage({
      type: 'request', body: fields.join('\t'),
    }, 'http://127.0.0.1:27182');
    this._showToast('Working…');
  }
  _showToast(message) {
    this.toastText = message;
    this.$.toast.show();
  }
  _connectDaemon() {
    this._daemonTimer = setTimeout(() => {
      if (this.daemonStatus === 'Connecting to Modmium') {
        this.daemonStatus = 'Service unavailable';
      }
    }, 3000);
  }
  _handleDaemonMessage(event) {
    if (event.origin !== 'http://127.0.0.1:27182' ||
        event.source !== this.$.daemonBridge.contentWindow) {
      return;
    }
    if (event.data?.type === 'ready') {
      event.source.postMessage({type: 'request', body: 'health'}, event.origin);
      event.source.postMessage({type: 'request', body: 'state'}, event.origin);
      event.source.postMessage({type: 'request', body: 'menus'}, event.origin);
      return;
    }
    if (event.data?.type !== 'response' || typeof event.data.body !== 'string') return;

    clearTimeout(this._daemonTimer);
    try {
      const response = JSON.parse(event.data.body);
      if (response.status) {
        this.daemonStatus = response.status === 'ok' ?
          `Service ${response.serviceVersion}` : 'Service error';
      } else if (response.type === 'menus') {
        this.moshMenus = Object.fromEntries(response.menus.map(menu => [menu.id, menu]));
      } else if (response.type === 'state') {
        this.modmiumState = response;
      } else if (response.type === 'action' && response.ok) {
        const completedAction = this._pendingMoshAction;
        this._pendingMoshAction = null;
        if (completedAction?.nextAction) {
          this._runAction({
            ...completedAction.nextAction,
            successMessage: completedAction.successMessage || completedAction.message,
          });
          return;
        }
        this._showToast(completedAction?.successMessage || completedAction?.message || 'Done');
        event.source.postMessage({type: 'request', body: 'state'}, event.origin);
      } else if (response.error) {
        this._showToast(response.error);
        this._pendingMoshAction = null;
        event.source.postMessage({type: 'request', body: 'state'}, event.origin);
      }
    } catch {
      this.daemonStatus = 'Service error';
    }
  }
}
customElements.define(ModmiumSettingsUiElement.is, ModmiumSettingsUiElement);

window.addEventListener('load', () => {
  ColorChangeUpdater.forDocument().start();
});
