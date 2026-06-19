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

  if [[ -f /usr/lib64/libfakephysmem.so ]] && grep -q 'libfakephysmem.so' /etc/chrome_dev.conf 2>/dev/null; then
    systemblur=1
  else
    systemblur=0
  fi
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
    echo -e "Credits to shadowed1 and Pilot Bell for making this toggle"
    sleep 1
    # LSB Spoofing by and ARM64 support by shadowed1
    # Studio Microphone by Pilot Bell
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)    
    LSB_RELEASE="/etc/lsb-release"
    BACKUP="${LSB_RELEASE}.bak"
    BACKUP2="${LSB_RELEASE}.$(date +%Y%m%d-%H%M%S).bak"
    cp "$LSB_RELEASE" "$BACKUP"
    cp "$LSB_RELEASE" "$BACKUP2"
    DEVBOARD="https://commondatastorage.googleapis.com/chromeos-dev-installer/board"
    
    echo "${GREEN}Backed up as ${BOLD}$BACKUP ${RESET}${GREEN}and${BOLD} $BACKUP2${RESET}"
    
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        NEW_BOARD="octopus"
    elif [[ "$ARCH" == "aarch64" ]]; then
        NEW_BOARD="jacuzzi"
    else
        echo "${RED}Unsupported arch: ${BOLD}$ARCH ${RESET}"
        sleep 3
        exit 1
    fi
    
    echo "${BLUE}Arch: $ARCH -> spoofing board to: $NEW_BOARD${RESET}"
    
    BUILD=$(grep "^CHROMEOS_RELEASE_BUILD_NUMBER=" "$LSB_RELEASE" | cut -d= -f2)
    MILESTONE=$(grep "^CHROMEOS_RELEASE_CHROME_MILESTONE=" "$LSB_RELEASE" | cut -d= -f2)
    
    echo "${CYAN}Searching for valid versions for $NEW_BOARD -> $BUILD${RESET}"
    NEW_VERSION=""
    for PATCH in $(seq 0 99); do
        CANDIDATE="${BUILD}.${PATCH}.0"
        URL="${DEVBOARD}/${NEW_BOARD}/${CANDIDATE}/packages/Packages"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
        if [[ "$HTTP_CODE" == "200" ]]; then
            NEW_VERSION="$CANDIDATE"
            echo "${GREEN}Found valid version: $NEW_VERSION${RESET}"
            break
        fi
    done
    
    if [[ -z "$NEW_VERSION" ]]; then
        echo "${RED}ERROR: No valid version found for board '$NEW_BOARD' -> $BUILD ${RESET}"
        sleep 3
        exit 1
    fi
    
    sed -i \
        -e "s/^CHROMEOS_RELEASE_BOARD=.*/CHROMEOS_RELEASE_BOARD=${NEW_BOARD}/" \
        -e "s/^CHROMEOS_RELEASE_BUILDER_PATH=.*/CHROMEOS_RELEASE_BUILDER_PATH=${NEW_BOARD}-release\/R${MILESTONE}-${NEW_VERSION}/" \
        -e "s/^CHROMEOS_RELEASE_DESCRIPTION=.*/CHROMEOS_RELEASE_DESCRIPTION=${NEW_VERSION} (Official Build) stable-channel ${NEW_BOARD} /" \
        "$LSB_RELEASE"
    
    echo "${MAGENTA}"
    grep -E "BOARD|BUILDER_PATH|DESCRIPTION" "$LSB_RELEASE"
    echo "${RESET}"
    
    printf 'n\n' | dev_install
    
    # Thanks to Days for this syntax
    BOARD=$(grep ^CHROMEOS_RELEASE_BOARD /etc/lsb-release | cut -d= -f2 | sed 's/-signed//')
    VERSION=$(grep ^CHROMEOS_RELEASE_VERSION /etc/lsb-release | cut -d= -f2)
    PORTAGE_BINHOST="https://commondatastorage.googleapis.com/chromeos-dev-installer/board/${BOARD}/${VERSION}/packages"
    echo "PORTAGE_BINHOST=$PORTAGE_BINHOST"
    ldconfig
    PORTAGE_CONFIGROOT=/usr/local PORTAGE_BINHOST=$PORTAGE_BINHOST emerge --getbinpkg --usepkgonly --nodeps -v sys-devel/binutils
    
    ##############################################################
    
    unset LD_LIBRARY_PATH LD_PRELOAD
    
    sed -i '/libforcefm.so/d' /usr/share/cros/init/cras-env.sh 2>/dev/null || true
    
    rm -f \
      /usr/local/force_fm.S \
      /usr/local/force_fm.o \
      /usr/local/libforcefm.so \
      /usr/lib64/libforcefm.so
    
    dlcservice_util --install --id=nc-ap-dlc 2>&1 || true
    dlcservice_util --dlc_state --id=nc-ap-dlc 2>&1 || true
    
    ARCH=$(uname -m)
    
    case "${ARCH}" in
        aarch64)
            TARGET="aarch64-cros-linux-gnu"
            ;;
        x86_64)
            TARGET="x86_64-cros-linux-gnu"
            ;;
        *)
            echo "${RED}Unsupported architecture: ${ARCH}${RESET}"
            sleep 3
            exit 1
            ;;
    esac
    
    BINUTILS_VERSION=$(
        find "/usr/local/${TARGET}/binutils-bin" -mindepth 1 -maxdepth 1 -type d \
        | sed 's#.*/##' \
        | sort -V \
        | tail -n1
    )
    
    if [ -z "${BINUTILS_VERSION}" ]; then
        echo "Unable to determine binutils version for ${TARGET}" >&2
        exit 1
    fi
    
    B="/usr/local/${TARGET}/binutils-bin/${BINUTILS_VERSION}"
    
    if [ "${ARCH}" = "x86_64" ]; then
        BLIB="/usr/local/lib64/binutils/${TARGET}/${BINUTILS_VERSION}"
    else
        BLIB="/usr/local/lib/binutils/${TARGET}/${BINUTILS_VERSION}"
    fi
    
    if [ ! -d "$BLIB" ]; then
        BLIB=$(find /usr/local/lib64 /usr/local/lib \
            -path '*/debug*' -prune -o \
            -path "*/binutils/${TARGET}/${BINUTILS_VERSION}" \
            -type d -print 2>/dev/null | head -1)
        if [ -z "$BLIB" ]; then
            echo "Cannot find binutils lib dir for ${TARGET}/${BINUTILS_VERSION}" >&2
            exit 1
        fi
        echo "Auto-detected BLIB: $BLIB"
    fi
    
    if [ "${ARCH}" = "x86_64" ]; then
        cat >/usr/local/force_fm.S <<'EOF'
    .text
    .globl _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
    .type _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE, @function
    _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE:
        mov $1, %eax
        ret
    .size _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE, .-_ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
EOF
        LD_LIBRARY_PATH="$BLIB" "$B/as" --64 \
            -o /usr/local/force_fm.o /usr/local/force_fm.S
        LD_LIBRARY_PATH="$BLIB" "$B/ld" -shared \
            -o /usr/local/libforcefm.so /usr/local/force_fm.o
    
    else
        cat >/usr/local/force_fm.S <<'EOF'
    .text
    .globl _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
    .type _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE, @function
    _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE:
        mov  w0, #1
        ret
    .size _ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE, .-_ZN12segmentation17FeatureManagement16IsFeatureEnabledERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
EOF
        LD_LIBRARY_PATH="$BLIB" "$B/as" \
            -o /usr/local/force_fm.o /usr/local/force_fm.S
        LD_LIBRARY_PATH="$BLIB" "$B/ld" -shared \
            -o /usr/local/libforcefm.so /usr/local/force_fm.o
    fi
    
    if [ "$(uname -m)" = "x86_64" ]; then
        LD_LIBRARY_PATH="$BLIB" \
        "$B/as" --64 \
            -o /usr/local/force_fm.o \
            /usr/local/force_fm.S
    else
        LD_LIBRARY_PATH="$BLIB" \
        "$B/as" \
            -o /usr/local/force_fm.o \
            /usr/local/force_fm.S
    fi
    
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
    
      mv /etc/lsb-release.bak /etc/lsb-release
    echo -e "Exiting.."
    sleep 1.67
    exit 0 # w fix?
  else
    echo -e "Disabling Studio Mic..."
    sleep 1
    sed -i '/libforcefm.so/d' /usr/share/cros/init/cras-env.sh && rm -f /usr/local/force_fm.* /usr/local/libforcefm.so /usr/lib64/libforcefm.so && restart cras
  fi
}

systemBlur(){
  if [[ $systemblur == 0 ]]; then
    echo -e "Enabling System Blur..."
    echo -e "Credits to pilot bell for making this toggle!"
    sleep 1

    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)

    LSB_RELEASE="/etc/lsb-release"
    BACKUP="${LSB_RELEASE}.bak.systemblur"
    BACKUP2="${LSB_RELEASE}.$(date +%Y%m%d-%H%M%S).bak.systemblur"
    DEVBOARD="https://commondatastorage.googleapis.com/chromeos-dev-installer/board"

    cp "$LSB_RELEASE" "$BACKUP"
    cp "$LSB_RELEASE" "$BACKUP2"

    echo "${GREEN}Backed up as ${BOLD}$BACKUP ${RESET}${GREEN}and${BOLD} $BACKUP2${RESET}"

    ARCH=$(uname -m)

    if [[ "$ARCH" == "x86_64" ]]; then
      TARGET="x86_64-cros-linux-gnu"
      NEW_BOARD="octopus"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      TARGET="aarch64-cros-linux-gnu"
      NEW_BOARD="jacuzzi"
    else
      echo "${RED}Unsupported arch: ${BOLD}$ARCH ${RESET}"
      sleep 3
      return 1
    fi

    echo "${BLUE}Arch: $ARCH -> spoofing board to: $NEW_BOARD${RESET}"

    BUILD=$(grep "^CHROMEOS_RELEASE_BUILD_NUMBER=" "$LSB_RELEASE" | cut -d= -f2)
    MILESTONE=$(grep "^CHROMEOS_RELEASE_CHROME_MILESTONE=" "$LSB_RELEASE" | cut -d= -f2)

    echo "${CYAN}Searching for valid versions for $NEW_BOARD -> $BUILD${RESET}"

    NEW_VERSION=""
    for PATCH in $(seq 0 99); do
      CANDIDATE="${BUILD}.${PATCH}.0"
      URL="${DEVBOARD}/${NEW_BOARD}/${CANDIDATE}/packages/Packages"
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

      if [[ "$HTTP_CODE" == "200" ]]; then
        NEW_VERSION="$CANDIDATE"
        echo "${GREEN}Found valid version: $NEW_VERSION${RESET}"
        break
      fi
    done

    if [[ -z "$NEW_VERSION" ]]; then
      cp "$BACKUP" "$LSB_RELEASE"
      echo "${RED}ERROR: No valid version found for board '$NEW_BOARD' -> $BUILD ${RESET}"
      sleep 3
      return 1
    fi

    sed -i \
      -e "s/^CHROMEOS_RELEASE_BOARD=.*/CHROMEOS_RELEASE_BOARD=${NEW_BOARD}/" \
      -e "s/^CHROMEOS_RELEASE_BUILDER_PATH=.*/CHROMEOS_RELEASE_BUILDER_PATH=${NEW_BOARD}-release\/R${MILESTONE}-${NEW_VERSION}/" \
      -e "s/^CHROMEOS_RELEASE_DESCRIPTION=.*/CHROMEOS_RELEASE_DESCRIPTION=${NEW_VERSION} (Official Build) stable-channel ${NEW_BOARD} /" \
      "$LSB_RELEASE"

    echo "${MAGENTA}"
    grep -E "BOARD|BUILDER_PATH|DESCRIPTION" "$LSB_RELEASE"
    echo "${RESET}"

    printf 'n\n' | dev_install

    BOARD=$(grep ^CHROMEOS_RELEASE_BOARD /etc/lsb-release | cut -d= -f2 | sed 's/-signed//')
    VERSION=$(grep ^CHROMEOS_RELEASE_VERSION /etc/lsb-release | cut -d= -f2)
    PORTAGE_BINHOST="https://commondatastorage.googleapis.com/chromeos-dev-installer/board/${BOARD}/${VERSION}/packages"

    echo "PORTAGE_BINHOST=$PORTAGE_BINHOST"

    ldconfig

    PORTAGE_CONFIGROOT=/usr/local \
    PORTAGE_BINHOST=$PORTAGE_BINHOST \
    emerge --getbinpkg --usepkgonly --nodeps -v sys-devel/binutils

    EMERGE_STATUS=$?

    cp "$BACKUP" "$LSB_RELEASE"

    if [[ "$EMERGE_STATUS" != "0" ]]; then
      echo "${RED}ERROR: Failed to install binutils${RESET}"
      sleep 3
      return 1
    fi

    BINUTILS_VERSION=$(
      find "/usr/local/${TARGET}/binutils-bin" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
      | sed 's#.*/##' \
      | sort -V \
      | tail -n1
    )

    if [[ -z "$BINUTILS_VERSION" ]]; then
      echo "${RED}ERROR: Unable to determine binutils version for $TARGET${RESET}"
      sleep 3
      return 1
    fi

    B="/usr/local/${TARGET}/binutils-bin/${BINUTILS_VERSION}"

    if [[ "$ARCH" == "x86_64" ]]; then
      BLIB="/usr/local/lib64/binutils/${TARGET}/${BINUTILS_VERSION}"
    else
      BLIB="/usr/local/lib/binutils/${TARGET}/${BINUTILS_VERSION}"
    fi

    if [[ ! -d "$BLIB" ]]; then
      BLIB=$(
        find /usr/local/lib64 /usr/local/lib \
          -path '*/debug*' -prune -o \
          -path "*/binutils/${TARGET}/${BINUTILS_VERSION}" \
          -type d -print 2>/dev/null \
        | head -1
      )
    fi

    if [[ ! -x "$B/as" || ! -x "$B/ld" || ! -d "$BLIB" ]]; then
      echo "${RED}ERROR: Binutils install is incomplete for $TARGET/$BINUTILS_VERSION${RESET}"
      sleep 3
      return 1
    fi

    echo "${CYAN}Using binutils: $B${RESET}"
    echo "${CYAN}Using binutils libs: $BLIB${RESET}"

    unset LD_LIBRARY_PATH LD_PRELOAD

    sed -i '/libfakephysmem.so/d' /etc/chrome_dev.conf 2>/dev/null || true

    rm -f \
      /usr/local/fakephysmem.S \
      /usr/local/fakephysmem.o \
      /usr/local/libfakephysmem.so \
      /usr/lib64/libfakephysmem.so

    if [[ "$ARCH" == "x86_64" ]]; then
      cat >/usr/local/fakephysmem.S <<'EOF'
.text
.globl sysconf
.type sysconf, @function
sysconf:
    push %rbp
    mov %rsp, %rbp
    sub $16, %rsp
    mov %rdi, -8(%rbp)
    cmp $85, %edi
    jne real_sysconf
    mov $2097152, %rax
    leave
    ret

real_sysconf:
    mov real_sysconf_ptr(%rip), %rax
    test %rax, %rax
    jne call_real
    mov $-1, %rdi
    lea sysconf_name(%rip), %rsi
    call dlsym@PLT
    mov %rax, real_sysconf_ptr(%rip)

call_real:
    mov -8(%rbp), %rdi
    call *%rax
    leave
    ret

.section .rodata
sysconf_name:
    .string "sysconf"

.bss
.align 8
real_sysconf_ptr:
    .quad 0
EOF

      LD_LIBRARY_PATH="$BLIB" "$B/as" --64 \
        -o /usr/local/fakephysmem.o \
        /usr/local/fakephysmem.S
    else
      cat >/usr/local/fakephysmem.S <<'EOF'
.text
.globl sysconf
.type sysconf, %function
sysconf:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x0, [sp, #16]
    cmp x0, #85
    b.ne real_sysconf
    movz x0, #0x20, lsl #16
    ldp x29, x30, [sp], #32
    ret

real_sysconf:
    adrp x1, real_sysconf_ptr
    ldr x2, [x1, #:lo12:real_sysconf_ptr]
    cbnz x2, call_real
    mov x0, #-1
    adrp x1, sysconf_name
    add x1, x1, #:lo12:sysconf_name
    bl dlsym
    adrp x1, real_sysconf_ptr
    str x0, [x1, #:lo12:real_sysconf_ptr]
    mov x2, x0

call_real:
    ldr x0, [sp, #16]
    blr x2
    ldp x29, x30, [sp], #32
    ret

.section .rodata
sysconf_name:
    .string "sysconf"

.bss
.align 8
real_sysconf_ptr:
    .quad 0
EOF

      LD_LIBRARY_PATH="$BLIB" "$B/as" \
        -o /usr/local/fakephysmem.o \
        /usr/local/fakephysmem.S
    fi

    if [[ "$?" != "0" ]]; then
      echo "${RED}ERROR: Failed to create System Blur faker${RESET}"
      sleep 3
      return 1
    fi

    LD_LIBRARY_PATH="$BLIB" "$B/ld" -shared \
      -o /usr/local/libfakephysmem.so \
      /usr/local/fakephysmem.o

    if [[ "$?" != "0" ]]; then
      echo "${RED}ERROR: Failed to enable System Blur${RESET}"
      sleep 3
      return 1
    fi

    cp -f /usr/local/libfakephysmem.so /usr/lib64/libfakephysmem.so
    chown root:root /usr/lib64/libfakephysmem.so
    chmod 4755 /usr/lib64/libfakephysmem.so

    touch /etc/chrome_dev.conf
    cp -a /etc/chrome_dev.conf /etc/chrome_dev.conf.bak.systemblur 2>/dev/null || true
    sed -i '/libfakephysmem.so/d; /--enable-low-end-device-mode/d; /--disable-low-end-device-mode/d; /DisableSystemBlur/d' /etc/chrome_dev.conf
    printf '%s\n' 'LD_PRELOAD=libfakephysmem.so' >> /etc/chrome_dev.conf

    echo "${GREEN}System Blur enabled${RESET}"
    echo "${YELLOW}Restarting UI...${RESET}"
  else
    echo -e "Disabling System Blur..."
    sleep 1
    sed -i '/libfakephysmem.so/d' /etc/chrome_dev.conf 2>/dev/null || true
    rm -f \
      /usr/local/fakephysmem.S \
      /usr/local/fakephysmem.o \
      /usr/local/libfakephysmem.so \
      /usr/lib64/libfakephysmem.so
  fi

  restart ui
}


# -- MAIN SCRIPT --
tput civis # :whale:
menu_reset() {
  menuText="\nFeature Toggles (THIS ENABLES FEATURES THAT MAY NOT WORK ON YOUR DEVICE, USE AT YOUR OWN RISK)\n"
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
