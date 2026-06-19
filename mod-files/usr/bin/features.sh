#!/bin/bash
# written by DMD

# -- Pre TUI init --
stty -echo
echo -ne "\033]0;MOSH\007"
source /usr/lib/libmosh.sh
if [[ -d /usr/local/nix/store ]]; then
  # issues can get caused if a user has a custom shell.
  # before, this code only ran if .bashrc was sourced,
  # but the shell wouldn't open if .bashrc wasn't sourced
  # chicken and egg. we fix it here.
  if ! mountpoint -q /nix; then
    sudo mkdir -p /nix
    sudo mount --bind /usr/local/nix /nix
  fi
  source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  unset LD_LIBRARY_PATH
fi

# -- FUNCTIONS --
quit() {
  clear
  tput cnorm
  exit 0
}

checkStatus() {
  [[ "$(cat /run/libsegmentation/feature_device_info 2>/dev/null)" == "CAMQAg==" ]] && chromebookplus=1 || chromebookplus=0
  [[ -f /usr/lib64/libforcefm.so ]] && grep -q 'libforcefm.so' /usr/share/cros/init/cras-env.sh && studiomic=1 || studiomic=0
  grep -q -- '--disable-features=DisableSystemBlur' /etc/chrome_dev.conf && systemblur=1 || systemblur=0
}

chromebookPlus(){
  if [[ $chromebookplus == 0 ]]; then
  echo -e "Enabling Chromebook Plus features..."
  echo -e "Credits to Pilot Bell for making this toggle"
  sleep 1
  F='FeatureManagement16Desks,FeatureManagementBorealis,FeatureManagementConchGenAi,FeatureManagementCrosSodaConchLanguages,FeatureManagementDriveFsBulkPinning,FeatureManagementFeatureAwareDeviceDemoMode,FeatureManagementGameDashboardRecordGame,FeatureManagementGeminiAppPreinstall,FeatureManagementGrowthFramework,FeatureManagementHistoryEmbedding,FeatureManagementLiveTranslateCrOS,FeatureManagementLobster,FeatureManagementLocalImageSearch,FeatureManagementMahi,FeatureManagementMarkupPod,FeatureManagementOobeAiIntro,FeatureManagementOobeGeminiIntro,FeatureManagementOobeSimon,FeatureManagementOrca,FeatureManagementRoundedWindows,FeatureManagementSeaPen,FeatureManagementShouldExcludeFromSysUiHoldback,FeatureManagementShowoff,FeatureManagementSystemLiveCaption,FeatureManagementTimeOfDayScreenSaver,FeatureManagementTimeOfDayWallpaper,FeatureManagementVideoConference'; printf 'description "Force Chromebook Plus feature management"\nstart on startup\ntask\nscript\n  mkdir -p /run/libsegmentation\n  printf %%s CAMQAg== >/run/libsegmentation/feature_device_info\nend script\n' >/etc/init/feature-plus.conf; chmod 644 /etc/init/feature-plus.conf; mkdir -p /run/libsegmentation; printf %s CAMQAg== >/run/libsegmentation/feature_device_info; sed -i '/^!?--feature-management-level=/d;/^!?--feature-management-max-level=/d;/^!?--feature-management-scope=/d;/FeatureManagement/d;/disable-extensions-except/d;/load-extension/d;/allowlisted-extension-id/d' /etc/chrome_dev.conf 2>/dev/null; printf '%s\n' '!--feature-management-level=' '!--feature-management-max-level=' '!--feature-management-scope=' '--feature-management-level=2' '--feature-management-max-level=2' '--feature-management-scope=1' "--enable-features=$F" >>/etc/chrome_dev.conf; restart ui
  else
    echo "Disabling Chromebook Plus features..."
    sleep 1
    rm /etc/init/feature-plus.conf; rm -f /run/libsegmentation/feature_device_info; sed -i '/^!?--feature-management-level=/d;/^!?--feature-management-max-level=/d;/^!?--feature-management-scope=/d;/FeatureManagement/d' /etc/chrome_dev.conf 2>/dev/null; restart ui
  fi
}
studioMic(){
  if [[ $studiomic == 0 ]]; then
    echo -e "Enabling Studio Mic..."
    echo -e "Credits to Pilot Bell for making this toggle"
    sleep 1
    unset LD_LIBRARY_PATH LD_PRELOAD
    sed -i '/libforcefm.so/d' /usr/share/cros/init/cras-env.sh 2>/dev/null || true
    
    rm -f \
      /usr/local/force_fm.S \
      /usr/local/force_fm.o \
      /usr/local/libforcefm.so \
      /usr/lib64/libforcefm.so
    
    dlcservice_util --install --id=nc-ap-dlc 2>&1 || true
    dlcservice_util --dlc_state --id=nc-ap-dlc 2>&1 || true
    
    B=/usr/local/x86_64-cros-linux-gnu/binutils-bin/2.45
    BLIB=/usr/local/lib64/binutils/x86_64-cros-linux-gnu/2.45
    
    cat >/usr/local/force_fm.S <<'EOF'
    .text
    .globl _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
    .type _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE, @function
    _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE:
      mov $1, %eax
      ret
    .size _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE, .-_ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
EOF
    
    LD_LIBRARY_PATH="$BLIB" \
      "$B/as" --64 \
      -o /usr/local/force_fm.o \
      /usr/local/force_fm.S
    
    LD_LIBRARY_PATH="$BLIB" \
      "$B/ld" -shared \
      -o /usr/local/libforcefm.so \
      /usr/local/force_fm.o
    
    cp -f /usr/local/libforcefm.so /usr/lib64/libforcefm.so
    chown root:root /usr/lib64/libforcefm.so
    chmod 4755 /usr/lib64/libforcefm.so
    
    echo 'export LD_PRELOAD="libforcefm.so${LD_PRELOAD:+:$LD_PRELOAD}"' \
      >> /usr/share/cros/init/cras-env.sh
    
    restart cras
    sleep 2
    
    grep -F libforcefm /proc/$(pidof cras)/maps || echo 'not loaded'
    
    dbus-send \
      --system \
      --print-reply \
      --dest=org.chromium.cras \
      /org/chromium/cras \
      org.chromium.cras.Control.GetAudioEffectDlcs
    
    dbus-send \
      --system \
      --print-reply \
      --dest=org.chromium.cras \
      /org/chromium/cras \
      org.chromium.cras.Control.IsStyleTransferSupported
    
    dbus-send \
      --system \
      --print-reply \
      --dest=org.chromium.cras \
      /org/chromium/cras \
      org.chromium.cras.Control.GetVoiceIsolationUIAppearance
  else
    echo -e "Disabling Studio Mic..."
    sleep 1
    sed -i '/libforcefm.so/d' /usr/share/cros/init/cras-env.sh 2>/dev/null; rm -f /usr/local/force_fm.S /usr/local/force_fm.o /usr/local/libforcefm.so /usr/lib64/libforcefm.so; dlcservice_util --uninstall --id=nc-ap-dlc 2>&1; restart cras
  fi
}

systemBlur(){
  if [[ $systemblur == 0 ]]; then
    echo -e "Enabling System Blur..."
    echo -e "Credits to Pilot Bell for making this toggle"
    sleep 1
    echo "--disable-features=DisableSystemBlur" >> /etc/chrome_dev.conf
  else
    echo -e "Disabling System Blur..."
    sleep 1
    sed -i '/--disable-features=DisableSystemBlur/d' /etc/chrome_dev.conf
  fi
  restart ui
}


# -- MAIN SCRIPT --
tput civis # :whale:
menu_reset() {
  menuText="\nFeature Toggles (THIS IS IN DEVELOPMENT, USE AT YOUR OWN RISK)\n"
  options=()
  checkStatus
  if [[ $chromebookplus == 1 ]]; then
    options+=("Toggle Chromebook Plus features [ON]")
  else
    options+=("Toggle Chromebook Plus features [OFF]")
  fi
  if [[ $studiomic == 1 ]]; then
    options+=("Toggle Studio Mic [ON]")
  else
    options+=("Toggle Studio Mic [OFF]")
  fi
  if [[ $systemblur == 1 ]]; then
    options+=("Toggle System Blur [ON]")
  else
    options+=("Toggle System Blur [OFF]")
  fi
  options+=("Exit")
  functions=("chromebookPlus" "studioMic" "systemBlur" "quit")
  num_options=${#options[@]}
}

menu_reset
clear
full_menu
tput cnorm
selector
