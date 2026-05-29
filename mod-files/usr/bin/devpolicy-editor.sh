#!/bin/bash
# written by mariah carey

source /root/.bashrc # to get $EDITOR
cd /usr/local/share/.policy-test-tool
jsonFile="dump.json"
DEVINSTALL_FILE="/mnt/stateful_partition/.devinstall_complete"

stty -echo
tput civis
clear

source /usr/lib/libmosh.sh

if [[ ! -f $jsonFile ]]; then
 	source /etc/profile # emerge breaks without this
	echo -e "${B}Installing required dependencies...${N}"
	if [[ ! -f $DEVINSTALL_FILE ]]; then
	  nohup dev_install --reinstall --yes >/root/.devinstall-log 2>&1 &
		echo -e "${G}Waiting for python dependencies from dev_install...${N}"
		pythonGoogleInstalled=$FLAGS_FALSE
		while [[ $pythonGoogleInstalled == $FLAGS_FALSE ]]; do
		  output=$(python -m google 2>&1)
			if [[ $output == *"package"* ]]; then
		    pythonGoogleInstalled=$FLAGS_TRUE
		  fi
			sleep 1
		done
		# cleaning up
		rm -rf /root/.devinstall_log
		touch $DEVINSTALL_FILE
	fi
	ldconfig # emerge breaks without this too
	emerge cryptography nano pyyaml &> /dev/null
	echo -e "${B}Dumping device policy to json...${N}"
	python devpol.py --dump --input $(ls /var/lib/devicesettings/policy.* | sort -V | tail -n 1) --output dump.json
	echo -e "${G}Done! Starting editor...${N}"
	sleep 2
	stty -echo
	tput civis
	clear
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
	local currentType=$(jq -r --arg k "$key" '.device[$k] | type' "$jsonFile")
	local currentVal=$(jq -r --arg k "$key" '.device[$k]' "$jsonFile")

	if [ "$currentType" == "boolean" ]; then
		newVal="true"; [ "$currentVal" == "true" ] && newVal="false"
		jq --arg k "$key" --argjson v "$newVal" '.device[$k] = $v' "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
	elif [[ "$currentType" == "string" ]]; then
		if [[ "$currentVal" =~ ^[\{\[] ]] && echo "$currentVal" | jq . >/dev/null 2>&1; then
			allowInput
			echo -e "${Y}Editing compressed object for ${N}$key"
			confirmOrCancel || { disallowInput; return; }
			echo "$currentVal" | jq . > "/tmp/mosh_tmp.json"
			"${EDITOR:-nano}" "/tmp/mosh_tmp.json"
			if jq . "/tmp/mosh_tmp.json" &>/dev/null; then
				local minified=$(jq -c . "/tmp/mosh_tmp.json")
				jq --arg k "$key" --arg v "$minified" '.device[$k] = $v' "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
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
			jq --arg k "$key" --arg v "$newval" '.device[$k] = $v' "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
			disallowInput
		fi
	elif [ "$currentType" == "number" ]; then
		allowInput
		echo -e "${B}Editing ${N}$key"
		confirmOrCancel || { disallowInput; return; }
		read -p "Enter new value: " newval
		jq --arg k "$key" --argjson v "$newval" '.device[$k] = $v' "$jsonFile" > "${jsonFile}.tmp" 2>/dev/null
		if [ $? -eq 0 ]; then mv "${jsonFile}.tmp" "$jsonFile"; fi
		disallowInput
	else
		allowInput
		echo -e "${Y}Warning: $key is a complicated object.${N}"
		confirmOrCancel || { disallowInput; return; }
		jq --arg k "$key" '.device[$k]' "$jsonFile" > "/tmp/mosh_tmp.json"
		"${EDITOR:-nano}" "/tmp/mosh_tmp.json"
		if jq . "/tmp/mosh_tmp.json" &>/dev/null; then
			jq --arg k "$key" --argjson v "$(< /tmp/mosh_tmp.json)" '.device[$k] = $v' "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"
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
			local val=$(jq -r --arg k "$k" '.device[$k]' "$jsonFile")
			local vtype=$(jq -r --arg k "$k" '.device[$k] | type' "$jsonFile")
			local dispName="${k:0:28}"
			[[ ${#k} -gt 28 ]] && dispName="${dispName}.."
			if [ "$vtype" == "boolean" ]; then
				[[ "$val" == "true" ]] && options+=("[${G}ON${N}]  $dispName") || options+=("[${R}OFF${N}] $dispName")
			elif [ "$vtype" == "array" ] || [ "$vtype" == "object" ]; then
				options+=("[${Y}{..}${N}] $dispName")
			else
				if [[ "$vtype" == "string" && "$val" =~ ^[\{\[] ]] && echo "$val" | jq . >/dev/null 2>&1; then
					options+=("[${Y}{\"${N}] $dispName")
				else
					local dispVal="${val:0:12}"
					[[ ${#val} -gt 12 ]] && dispVal="${dispVal}.."
					options+=("[${B}${dispVal//$'\n'/ }${N}] $dispName")
				fi
			fi
		done
		options+=("<-- Back")
	}

	clear
	loadData
	while :; do
		local numOptions=${#options[@]}
		local termHeight=$(tput lines)
		local termWidth=$(tput cols)
		local maxRows=$((termHeight - 6))
		local colWidth=42
		local numCols=$((termWidth / colWidth))
		[[ $numCols -lt 1 ]] && numCols=1

		local itemsPerPage=$((maxRows * numCols))
		local currentPage=$((subSelectedIndex / itemsPerPage))
		local pageStart=$((currentPage * itemsPerPage))

		tput cup 0 0
		echo -e "${P}=== $title (Page $((currentPage + 1))) ===${N}"

		for r in $(seq 0 $((maxRows - 1))); do
			tput cup $((r + 2)) 0
			for c in $(seq 0 $((numCols - 1))); do
				local idx=$((pageStart + r + (c * maxRows)))
				if [ $idx -lt $numOptions ]; then
					local out="${options[$idx]}"
					if [ $idx -eq $subSelectedIndex ]; then
						printf "\e[7m %-${colWidth}s \e[0m" "$out"
					else
						printf " %-${colWidth}s " "$out"
					fi
				fi
			done
			tput el
		done
		tput ed

		read -rsn1 key
		if [[ "$key" == $'\x1b' ]]; then
			read -rsn2 -t 0.05 keyseq
			while read -rsn1 -t 0.01 _; do :; done
			[[ -z "$keyseq" ]] && break
			case "$keyseq" in
				'[A') subSelectedIndex=$(((subSelectedIndex - 1 + numOptions) % numOptions)) ;;
				'[B') subSelectedIndex=$(((subSelectedIndex + 1) % numOptions)) ;;
				'[C') [[ $((subSelectedIndex + maxRows)) -lt $numOptions ]] && subSelectedIndex=$((subSelectedIndex + maxRows)) ;;
				'[D') [[ $((subSelectedIndex - maxRows)) -ge 0 ]] && subSelectedIndex=$((subSelectedIndex - maxRows)) ;;
			esac
		elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
			break
		elif [[ "$key" == "" ]]; then
			if [ $subSelectedIndex -eq $((numOptions - 1)) ]; then
				break
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
	echo -e "Use arrows to navigate. Enter to select. Esc to go back."
}

mainMenuOptions=("1) Restrictions" "2) Reporting" "3) Enterprise Settings" "4) Misc" "5) Apply Policies" "6) Reset All Changes")
mainSelectedIndex=0
mainNumOptions=${#mainMenuOptions[@]}

full_menu(){
	while :; do
		tput cup 0 0
		main_menu_logo
		echo ""
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
			while read -rsn1 -t 0.01 _; do :; done
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
					python devpol.py $jsonFile && exit 0 || { sleep 2; disallowInput; } ;;
				5)
					allowInput
					echo -e "${Y}Reverting changes!${N}"
					pushd /var/lib/devicesettings &> /dev/null
					mv owner.key.bak.enterprise owner.key &> /dev/null
					local policyBackup=$(ls policy.*.bak.enterprise 2>/dev/null)
					[[ -n "$policyBackup" ]] && mv "$policyBackup" "${policyBackup%.bak.enterprise}" &> /dev/null
					popd &> /dev/null
					rm -rf $jsonFile
					echo -e "${G}Done!${N}"; sleep 2; exit 0 ;;
			esac
			clear
		fi
	done
}

full_menu
