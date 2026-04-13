#!/bin/bash
# written by mariah carey	

cd /usr/local/share/policy-test-tool
jsonFile="dump.json"

stty -echo
tput civis
clear

# TUI colors :D
B=$'\033[38;5;45m'
G=$'\033[38;5;46m'
Y=$'\033[38;5;220m'
R=$'\033[38;5;203m'
P=$'\033[38;5;135m'
N=$'\033[0m'
D=$'\033[1;90m'

if [[ ! -f $jsonFile ]]; then
	echo -e "${B}Installing required dependencies...${N}"
	source /etc/profile # emerge breaks without this
	ldconfig # emerge breaks without this too
	emerge cryptography nano pyyaml &> /dev/null
	echo -e "${B}Dumping device policy to json...${N}"
	python devpol.py --dump --input $(ls /var/lib/devicesettings/policy.* | sort -V | tail -n 1) --output dump.json
	echo -e "${G}Done! Starting editor...${N}"
	sleep 2
fi

# there's gotta be a better way to do this but whatever :sob:
RESTRICTIONS=(
	"DeviceGuestModeEnabled" "DeviceShowUserNamesOnSignin" "DeviceAllowNewUsers"
	"DeviceBlockDevmode" "DeviceUnaffiliatedCrostiniAllowed" "PluginVmAllowed"
	"DeviceUserAllowlist" "DeviceUserWhitelist" "DeviceFamilyLinkAccountsAllowed"
	"DeviceBorealisAllowed" "VirtualMachinesAllowed" "UnaffiliatedArcAllowed"
	"SupervisedUsersEnabled" "DeviceAllowRedeemChromeOsRegistrationOffers"
	"DeviceRestrictedManagedGuestSessionEnabled" "DeviceCrostiniArcAdbSideloadingAllowed"
	"DeviceLoginScreenExtensionManifestV2Availability" "DeviceExtensionsSystemLogEnabled"
	"DeviceEphemeralUsersEnabled" "DeviceDebugPacketCaptureAllowed"
)

REPORTING=(
	"ReportDeviceVersionInfo" "ReportDeviceActivityTimes" "ReportDeviceBootMode"
	"ReportDeviceNetworkInterfaces" "ReportDeviceUsers" "ReportDeviceHardwareStatus"
	"ReportDeviceSessionStatus" "ReportDeviceOsUpdateStatus" "ReportDeviceRunningKioskApp"
	"ReportDevicePowerStatus" "ReportDeviceStorageStatus" "ReportDeviceBoardStatus"
	"ReportDeviceCpuInfo" "ReportDeviceGraphicsStatus" "ReportDeviceCrashReportInfo"
	"ReportDeviceTimezoneInfo" "ReportDeviceMemoryInfo" "ReportDeviceBacklightInfo"
	"ReportDeviceBluetoothInfo" "ReportDeviceFanInfo" "ReportDeviceVpdInfo"
	"ReportDeviceSystemInfo" "ReportDevicePrintJobs" "ReportDeviceLoginLogout"
	"ReportDeviceAudioStatus" "ReportDeviceNetworkConfiguration" "ReportDeviceNetworkStatus"
	"ReportDeviceSecurityStatus" "ReportCRDSessions" "ReportDevicePeripherals"
	"DeviceReportNetworkEvents" "DeviceReportRuntimeCounters" "ReportUploadFrequency"
	"ReportDeviceNetworkTelemetryCollectionRateMs" "ReportDeviceAudioStatusCheckingRateMs"
	"ReportDeviceAppInfo" "ReportDeviceLocation" "ReportDeviceNetworkTelemetryEventCheckingRateMs"
	"ReportDeviceSignalStrengthEventDrivenTelemetry" "DeviceReportRuntimeCountersCheckingRateMs"
	"DeviceReportXDREvents" "EnableDeviceGranularReporting" "HeartbeatFrequency"
	"DeviceActivityHeartbeatCollectionRateMs" "DeviceActivityHeartbeatEnabled"
	"HeartbeatEnabled" "LogUploadEnabled"
)

ENTERPRISE=(
	"DeviceOpenNetworkConfiguration" "DevicePrinters" "DevicePrintersAccessMode"
	"DeviceLocalAccounts" "AllowKioskAppControlChromeVersion"
	"KioskCRXManifestUpdateURLIgnored" "DeviceLoginScreenDomainAutoComplete"
	"DeviceNativePrinters" "DeviceNativePrintersAccessMode" "DeviceNativePrintersBlacklist"
	"DeviceNativePrintersWhitelist" "DevicePrintersAllowlist" "DevicePrintersBlocklist"
	"DevicePrintingClientNameTemplate" "DeviceExternalPrintServers"
	"DeviceExternalPrintServersAllowlist" "DeviceHostnameTemplate"
	"DeviceHostnameUserConfigurable" "RequiredClientCertificateForDevice"
	"SystemProxySettings" "DeviceAllowEnterpriseRemoteAccessConnections"
	"DeviceWebBasedAttestationAllowedUrls" "DeviceLoginScreenAutoSelectCertificateForUrls"
	"DeviceLoginScreenSecurityKeyPermitAttestation" "DeviceLoginScreenContextAwareAccessSignalsAllowlist"
	"DeviceAuthenticationURLAllowlist" "DeviceAuthenticationURLBlocklist"
	"DeviceGpoCacheLifetime" "DeviceKerberosEncryptionTypes" "DeviceMachinePasswordChangeRate"
	"LoginVideoCaptureAllowedUrls" "DeviceLoginScreenExtensions"
	"DeviceLoginScreenInputMethods" "DeviceLoginScreenLocales"
	"ManagedGuestSessionPrivacyWarningsEnabled" "DeviceLocalAccountAutoLoginId"
	"DeviceLocalAccountAutoLoginDelay" "DeviceLocalAccountAutoLoginBailoutEnabled"
	"DeviceLocalAccountPromptForNetworkWhenOffline"
)

MISC=(
	"DeviceDataRoamingEnabled" "DeviceMetricsReportingEnabled" "ChromeOsReleaseChannel"
	"ChromeOsReleaseChannelDelegated" "SystemTimezone" "SystemTimezoneAutomaticDetection"
	"SystemUse24HourClock" "UptimeLimit" "AttestationEnabledForDevice"
	"AttestationForContentProtectionEnabled" "NetworkThrottlingEnabled"
	"DeviceEcryptfsMigrationStrategy" "DeviceWiFiFastTransitionEnabled"
	"DeviceAutoUpdateDisabled" "DeviceTargetVersionPrefix" "DeviceUpdateScatterFactor"
	"DeviceUpdateAllowedConnectionTypes" "DeviceUpdateHttpDownloadsEnabled"
	"RebootAfterUpdate" "DeviceRollbackToTargetVersion" "DeviceAutoUpdateTimeRestrictions"
	"DeviceWiFiAllowed" "DeviceAutoUpdateP2PEnabled" "DeviceUpdateStagingSchedule"
	"DeviceScheduledUpdateCheck" "DeviceTargetVersionSelector" "DeviceReleaseLtsTag"
	"DeviceRollbackAllowedMilestones" "DeviceChannelDowngradeBehavior"
	"DeviceExtendedAutoUpdateEnabled" "DeviceQuickFixBuildToken" "DeviceMinimumVersion"
	"DeviceMinimumVersionAueMessage" "MinimumRequiredChromeVersion"
	"DeviceScheduledReboot" "DeviceRebootOnShutdown" "DeviceRebootOnUserSignout"
	"DevicePowerwashAllowed" "DeviceRunAutomaticCleanupOnLogin" "AutoCleanUpStrategy"
	"DeviceShowLowDiskSpaceNotification" "DeviceAllowMGSToStoreDisplayProperties"
	"DeviceSecondFactorAuthentication" "DeviceLoginScreenGeolocationAccessLevel"
	"DeviceEphemeralNetworkPoliciesEnabled" "DeviceEncryptedReportingPipelineEnabled"
	"DeviceSystemWideTracingEnabled" "DevicePolicyRefreshRate" "DeviceVariationsRestrictParameter"
	"DeviceChromeVariations" "DeviceUserPolicyLoopbackProcessingMode"
	"DeviceKeylockerForStorageEncryptionEnabled" "DevicePciPeripheralDataAccessEnabled"
	"DeviceNativeClientForceAllowed" "DeviceQuirksDownloadEnabled"
	"DeviceHardwareVideoDecodingEnabled" "DeviceUserInitiatedFirmwareUpdatesEnabled"
	"DeviceUserInitiatedFlexSystemFirmwareUpdatesEnabled" "DeviceFlexArcPreloadEnabled"
	"DeviceFlexHwDataForProductImprovementEnabled"
	"DeviceArcDataSnapshotHours" "ChromadToCloudMigrationEnabled"
	"DeviceTransferSAMLCookies" "DeviceAutofillSAMLUsername"
	"DeviceLoginScreenIsolateOrigins" "DeviceLoginScreenSitePerProcess"
	"DeviceLoginScreenPreferSlowCiphers" "DeviceLoginScreenPreferSlowKexAlgorithms"
	"DeviceLoginScreenWebHidAllowDevicesForUrls" "DeviceLoginScreenWebUsbAllowDevicesForUrls"
	"DeviceLoginScreenPowerManagement" "DeviceWeeklyScheduledSuspend"
	"DeviceRestrictionSchedule" "DevicePowerPeakShiftEnabled"
	"DevicePowerPeakShiftBatteryThreshold" "DevicePowerPeakShiftDayConfig"
	"DeviceAdvancedBatteryChargeModeEnabled" "DeviceAdvancedBatteryChargeModeDayConfig"
	"DeviceBatteryChargeMode" "DeviceBatteryChargeCustomStartCharging"
	"DeviceBatteryChargeCustomStopCharging" "DevicePowerBatteryChargingOptimization"
	"DeviceBootOnAcEnabled" "DeviceUsbPowerShareEnabled" "DeviceChargingSoundsEnabled"
	"DeviceLowBatterySoundEnabled" "DeviceAllowBluetooth" "DeviceAllowedBluetoothServices"
	"DeviceBluetoothJustWorksPairingEnabled" "DeviceWilcoDtcAllowed"
	"DeviceWilcoDtcConfiguration" "DeviceSystemAecEnabled" "DeviceDisplayResolution"
	"DisplayRotationDefault" "DeviceDockMacAddressSource" "DeviceWallpaperImage"
	"CastReceiverName" "DeviceScreensaverLoginScreenEnabled"
	"DeviceScreensaverLoginScreenIdleTimeoutSeconds"
	"DeviceScreensaverLoginScreenImageDisplayIntervalSeconds"
	"DeviceScreensaverLoginScreenImages" "DeviceLoginScreenShowOptionsInSystemTrayMenu"
	"DeviceLoginScreenSystemInfoEnforced" "DeviceDlcPredownloadList" "ExtensionCacheSize"
	"DevicePostQuantumKeyAgreementEnabled" "DeviceHindiInscriptLayoutEnabled"
	"DeviceSwitchFunctionKeysBehaviorEnabled" "DeviceExtendedFkeysModifier"
	"DeviceI18nShortcutsEnabled" "DeviceKeyboardBacklightColor"
	"DeviceLoginScreenAccessibilityShortcutsEnabled"
	"DeviceLoginScreenDefaultHighContrastEnabled" "DeviceLoginScreenDefaultLargeCursorEnabled"
	"DeviceLoginScreenDefaultScreenMagnifierType" "DeviceLoginScreenDefaultSpokenFeedbackEnabled"
	"DeviceLoginScreenDefaultVirtualKeyboardEnabled" "DeviceLoginScreenHighContrastEnabled"
	"DeviceLoginScreenLargeCursorEnabled" "DeviceLoginScreenMonoAudioEnabled"
	"DeviceLoginScreenSpokenFeedbackEnabled" "DeviceLoginScreenStickyKeysEnabled"
	"DeviceLoginScreenAutoclickEnabled" "DeviceLoginScreenCaretHighlightEnabled"
	"DeviceLoginScreenCursorHighlightEnabled" "DeviceLoginScreenDictationEnabled"
	"DeviceLoginScreenFaceGazeEnabled" "DeviceLoginScreenKeyboardFocusHighlightEnabled"
	"DeviceLoginScreenPrivacyScreenEnabled" "DeviceLoginScreenSelectToSpeakEnabled"
	"DeviceLoginScreenTouchVirtualKeyboardEnabled" "DeviceLoginScreenVirtualKeyboardEnabled"
	"DeviceLoginScreenScreenMagnifierType" "DeviceLoginScreenPrimaryMouseButtonSwitch"
	"DeviceLoginScreenPromptOnMultipleMatchingCertificates"
	"DeviceShowNumericKeyboardForPassword" "DeviceAuthDataCacheLifetime"
	"DeviceAuthenticationFlowAutoReloadInterval" "PluginVmLicenseKey"
	"LoginAuthenticationBehavior"
)

allowInput(){
	stty echo
	tput cnorm
	clear
}
disallowInput(){
	stty -echo
	tput civis
	clear
}

confirmOrCancel(){
	case ${currentType} in
		'string')
			if [[ ! $currentVal =~ ^[\{\[] ]]; then
				echo "Current value: ${currentVal}"
			fi
			;;
		'number')
			echo "Current value: ${currentVal}"
			;;
	esac
	echo -e "${D}(Press Enter to edit, Esc to cancel)${N}"
	read -rsn1 k 
	[[ "$k" == $'\x1b' ]] && return 1
	return 0
}

editJsonValue(){
	local key="$1"
	local currentType=$(jq -r ".device.$key | type" $jsonFile)
	local currentVal=$(jq -r ".device.$key" $jsonFile)

	if [ "$currentType" == "boolean" ]; then
		if [ "$currentVal" == "true" ]; then
			jq ".device.$key = false" "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
		else
			jq ".device.$key = true" "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
		fi
	elif [[ "$currentType" == "string" ]]; then
		if [[ "$currentVal" =~ ^[\{\[] ]] && echo "$currentVal" | jq . >/dev/null 2>&1; then
			allowInput
			echo -e "${Y}Editing compressed object for ${N}$key"
			confirmOrCancel || { disallowInput; return; }
			echo "$currentVal" | jq . > "/tmp/mosh_tmp.json"
			"${EDITOR:-nano}" "/tmp/mosh_tmp.json"      
			if jq . "/tmp/mosh_tmp.json" &>/dev/null; then
   			local minified=$(jq -c . "/tmp/mosh_tmp.json")
				jq --arg newval "$minified" ".device.$key = \$newval" "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
			else
				echo -e "${R}Invalid syntax, changes discarded.${N}"
				sleep 2
			fi
			rm -f "/tmp/mosh_tmp.json"
			disallowInput
		else
			allowInput
			echo -e "${B}Editing ${N}$key"
			confirmOrCancel || { disallowInput; return; }
			read -p "Enter new value: " newval
			jq ".device.$key = \"$newval\"" "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
			disallowInput
		fi
	elif [ "$currentType" == "number" ]; then
		allowInput
		echo -e "${B}Editing ${N}$key"
		confirmOrCancel || { disallowInput; return; }
		read -p "Enter new value: " newval
		jq ".device.$key = $newval" "$jsonFile" > "${jsonFile}.tmp" 2>/dev/null
		if [ $? -eq 0 ]; then mv "${jsonFile}.tmp" "$jsonFile"; fi
		disallowInput
	else
		allowInput
		echo -e "${Y}Warning: $key is a complicated object.${N}"
		confirmOrCancel || { disallowInput; return; }
		jq ".device."$key"" "$jsonFile" > "/tmp/mosh_tmp.json"
		"${EDITOR:-nano}" "/tmp/mosh_tmp.json"    
		if jq . "/tmp/mosh_tmp.json" &>/dev/null; then
			jq --argfile newval "/tmp/mosh_tmp.json" ".device.$key = \$newval" "$jsonFile" > "${jsonFile}.tmp" && cp "${jsonFile}.tmp" "$jsonFile"
		else
			echo -e "${R}Invalid JSON syntax. Changes discarded.${N}"
			sleep 2
		fi
		rm -f "/tmp/mosh_tmp.json"
		disallowInput
  fi
}

submenu(){
	local title="$1"
	shift
	local keys=("$@")
	local subSelectedIndex=0
	local options=()
	loadData(){
		options=()
		for k in "${keys[@]}"; do
			local val=$(jq -r ".device.$k" "$jsonFile")
			local vtype=$(jq -r ".device.$k | type" "$jsonFile")
			local dispName="${k:0:35}"
			[[ ${#k} -gt 35 ]] && dispName="${dispName}..."
			if [ "$vtype" == "boolean" ]; then
				if [ "$val" == "true" ]; then 
					options+=("[${G}ON${N}]  $dispName")
				else 
					options+=("[${R}OFF${N}] $dispName")
				fi
			elif [ "$vtype" == "array" ] || [ "$vtype" == "object" ]; then
				options+=("[${Y}{..}${N}] $dispName")
			else
				if [[ "$vtype" == "string" && "$val" =~ ^[\{\[] ]] && echo "$val" | jq . >/dev/null 2>&1; then
					options+=("[${Y}{\"${N}] $dispName") 
				else
					local dispVal="${val:0:20}"
					[[ ${#val} -gt 20 ]] && dispVal="${dispVal}..."
					dispVal="${dispVal//$'\n'/ }"
					options+=("[${B}$dispVal${N}] $dispName")
				fi
			fi
		done
		options+=("<-- Back to Main Menu")
	}
	loadData
	clear

	while :; do
		clear
		echo -e "${P}=== $title ===${N}\n"
		local numOptions=${#options[@]}
		for i in "${!options[@]}"; do
			if [[ $i -eq $subSelectedIndex ]]; then
				printf "\e[7m > %-60s \e[0m\n" "${options[$i]}"
			else
				printf "   %-61s\n" "${options[$i]}"
			fi
		done
		read -rsn1 key
		if [[ "$key" == $'\x1b' ]]; then
			read -rsn2 -t 0.05 keyseq
			if [[ -z "$keyseq" ]]; then
				break # this one is to leave menu on escape
			fi
			case "$keyseq" in
				'[A') subSelectedIndex=$(((subSelectedIndex - 1 + numOptions) % numOptions)) ;;
				'[B') subSelectedIndex=$(((subSelectedIndex + 1) % numOptions)) ;;
			esac
		elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
			break # this one is to leave menu on backspace
		elif [[ "$key" == "" ]]; then
			if [ $subSelectedIndex -eq $((numOptions - 1)) ]; then
				break # and this little piggy is to quit when you hit the damn quit button
			else
				editJsonValue "${keys[$subSelectedIndex]}"
				loadData
				clear 
			fi
		fi
	done
	clear
}

main_menu_logo(){
	echo -e "${B}MOSH device policy editor${N}"
	echo -e "Press enter to select and esc to go back (from inside a submenu).\n To return to MOSH, press Ctrl+C"
}

mainMenuOptions=("1) Restrictions" "2) Reporting" "3) Enterprise Settings" "4) Misc" "5) Apply Policies (will restart ChromeOS UI)" "6) Reset All Changes")
mainSelectedIndex=0
mainNumOptions=${#mainMenuOptions[@]}

full_menu(){
	clear
	while :; do
		tput cup 0 0
		main_menu_logo
		for i in "${!mainMenuOptions[@]}"; do
			if [[ $i -eq $mainSelectedIndex ]]; then
				printf "\e[7m > %-40s \e[0m\n" "${mainMenuOptions[$i]}"
			else
				printf "   %-45s\n" "${mainMenuOptions[$i]}"
			fi
		done
		tput ed
        
		read -rsn1 key
		if [[ "$key" == $'\x1b' ]]; then
			read -rsn2 -t 0.05 keyseq
			case "$keyseq" in
				'[A') mainSelectedIndex=$(((mainSelectedIndex - 1 + mainNumOptions) % mainNumOptions)) ;;
				'[B') mainSelectedIndex=$(((mainSelectedIndex + 1) % mainNumOptions)) ;;
			esac
		elif [[ "$key" =~ [1-6] ]]; then
			mainSelectedIndex=$((key - 1))
		elif [[ "$key" == "" ]]; then
			case $mainSelectedIndex in
				0) submenu "Restrictions" "${RESTRICTIONS[@]}" ;;
				1) submenu "Reporting" "${REPORTING[@]}" ;;
				2) submenu "Enterprise Settings" "${ENTERPRISE[@]}" ;;
				3) submenu "Misc Settings" "${MISC[@]}" ;;
				4) 
					allowInput
					echo -e "${G}Applying device policies!${N}"
					python devpol.py $jsonFile
					exit 0 
					;;
				5)
					allowInput
					echo -e "${Y}Reverting changes!${N}"
					pushd /var/lib/devicesettings &> /dev/null
					mv owner.key.bak.enterprise owner.key &> /dev/null
					local policyBackup=$(ls policy.*.bak.enterprise 2>/dev/null)
					mv ${policyBackup} ${policyBackup%.bak.enterprise} &> /dev/null
					popd &> /dev/null
					rm -rf $jsonFile
					echo -e "${G}Done!${N}"
					sleep 2
					exit 0
				esac
		fi
	done
}

clear
full_menu
