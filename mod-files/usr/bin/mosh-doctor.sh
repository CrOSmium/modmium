#!/bin/bash
# written by Claude (self-check / doctor script)
# Runs a handful of read-only sanity checks and reports them in plain
# language, so a user can self-diagnose before asking for support.

source /usr/lib/libmosh.sh

PASS="${G}[ OK ]${N}"
WARN="${Y}[WARN]${N}"
FAIL="${R}[FAIL]${N}"

report() {
  # report <PASS|WARN|FAIL var> <message>
  echo -e "$1 $2"
}

clear
echo -e "${B}Modmium Health Check${N}"
echo -e "${D}Read-only checks, nothing here will change anything on your device.${N}\n"

# -- RootFS filesystem --
fstype=$(findmnt -no FSTYPE / 2>/dev/null)
if [[ "$fstype" == "ext4" ]]; then
  report "$PASS" "RootFS is ext4."
elif [[ "$fstype" == "ext2" ]]; then
  report "$WARN" "RootFS is still ext2 - it'll be upgraded to ext4 next time you change ChromeOS version."
else
  report "$FAIL" "Could not determine RootFS filesystem type (got '$fstype')."
fi

# -- Modmium identity files --
if [[ -f /usr/share/.version && -f /.branch ]]; then
  report "$PASS" "Modmium $(cat /usr/share/.version 2>/dev/null) ($(cat /.branch 2>/dev/null)) identity files present."
else
  report "$FAIL" "Missing /usr/share/.version or /.branch - this doesn't look like a normal Modmium install."
fi

# -- Dependency marker consistency --
if [[ -f $DEVINSTALL_MARKER ]]; then
  if which git &>/dev/null && which file &>/dev/null; then
    report "$PASS" "Dev packages marker present and git/file are actually installed."
  else
    report "$WARN" "Dev packages marker exists but git/file aren't on PATH. Run 'rm $DEVINSTALL_MARKER' then reopen a menu that needs them to force a clean reinstall."
  fi
else
  report "$WARN" "Dev packages haven't been installed yet on this boot of stateful (normal right after a powerwash) - they'll be installed automatically the next time something needs them."
fi

# -- Stateful free space --
freeKB=$(df /mnt/stateful_partition 2>/dev/null | awk 'NR==2 {print $4}')
if [[ -n $freeKB ]]; then
  freeMB=$((freeKB / 1024))
  if [[ $freeMB -lt 512 ]]; then
    report "$FAIL" "Only ${freeMB}MB free on stateful - installs and updates will likely fail. Free up space (Downloads, apps, etc)."
  elif [[ $freeMB -lt 2048 ]]; then
    report "$WARN" "Only ${freeMB}MB free on stateful - that's cutting it close for a ChromeOS reinstall."
  else
    report "$PASS" "${freeMB}MB free on stateful."
  fi
else
  report "$FAIL" "Could not read free space on stateful."
fi

# -- Internet connectivity --
if curl -fsSL --max-time 5 -o /dev/null "https://cdn.jsdelivr.net"; then
  report "$PASS" "Internet connectivity looks fine."
else
  report "$WARN" "Couldn't reach the internet just now - dependency installs, ChromeOS version changes, and updates all need it."
fi

# -- Firmware write protection / DevFW status --
writeprotect=$(flashrom --wp-status 2>&1 | grep "disabled")
if [[ -n $writeprotect ]]; then
  report "$PASS" "Firmware write protection is disabled."
else
  report "$WARN" "Firmware write protection is currently enabled - some menu options (enrollment, firmware tools) need it off."
fi

devfw=$(vpd -i RO_VPD -g "dev_firmware" 2>/dev/null)
if [[ "$devfw" == "1" ]]; then
  report "$PASS" "DevFW flag is set."
else
  report "$WARN" "DevFW flag is not set (unexpected if Modmium is fully installed and working)."
fi

# -- Recent failures in the shared Modmium log --
if [[ -f $MODMIUM_LOG ]]; then
  recentFails=$(grep "FAILED" "$MODMIUM_LOG" 2>/dev/null | tail -5)
  if [[ -n $recentFails ]]; then
    echo -e "\n${Y}Most recent failures logged (see $MODMIUM_LOG for the full history):${N}"
    echo "$recentFails"
  else
    report "$PASS" "No failures recorded in the Modmium log."
  fi
else
  echo -e "\n${D}No Modmium log yet at $MODMIUM_LOG - nothing has logged an action or failure since the last powerwash.${N}"
fi

echo ""
log_action "Ran health check"
read -n1 -rsp "Press any key to return to the menu..."
