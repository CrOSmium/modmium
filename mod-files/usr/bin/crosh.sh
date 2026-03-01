#!/bin/sh
# Copyright 2012 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

################################################################################
# DO NOT ADD ANY NEW COMMANDS IN HERE.
#
# This is the legacy shell code for commands that haven't been ported to Rust
# yet.  Any attempts to add new commands to here will be rejected.
################################################################################

# Disable path expansion at the command line.  None of our builtins need or want
# it, and it's safer to disallow it in the first place.
set -f

# Don't allow SIGHUP to terminate crosh. This guarantees that even if the user
# closes the crosh window, we make our way back up to the main loop, which gives
# cleanup code in command handlers a chance to run.
trap '' HUP

# If it exists, use $DATA_DIR to define the $HOME location, as a first step
# to entirely removing the use of $HOME. (Though HOME should be used as
# fall-back when DATA_DIR is unset.)
# TODO(keescook): remove $HOME entirely crbug.com/333031
# shellcheck disable=SC2154
if [ "${DATA_DIR+set}" = "set" ]; then
  export HOME="${DATA_DIR}/user"
fi

# Gets set to "1" when in dev mode.
CROSH_DEVMODE=1
# Gets set to "1" when running on removable media (e.g. USB stick).
CROSH_REMOVABLE=
CROSH_MODPATH="/usr/share/crosh"
# Gets set to "1" when a single command is being executed followed by exit.
CROSH_SINGLE_COMMAND=

check_digits() {
  expr "$1" : '^[[:digit:]]*$' > /dev/null
}

# Load all modules found in the specified subdir.
load_modules() {
  local subdir="$1"
  local dir="${CROSH_MODPATH}/${subdir}"
  local mod

  # Turn on path expansion long enough to find local modules.
  set +f
  for mod in "${dir}"/[0-9][0-9]-*.sh; do
    # Then turn path expansion back off.
    set -f
    if [ -e "${mod}" ]; then
      if [ "${CROSH_SINGLE_COMMAND}" != "1" ]; then
        echo "Loading extra module: ${mod}"
      fi
      # shellcheck disable=SC1090
      . "${mod}" || :
    fi
  done
}

load_extra_crosh() {
  # Load the removable modules, if the rootfs is on removable
  # media.  e.g. It's a USB stick.
  if [ "${CROSH_REMOVABLE}" = "1" ]; then
    load_modules "removable.d"
  fi

  # Load the dev-mode modules, if in dev mode, or if forced.
  # This comes last so it can override any release modules.
  if [ "${CROSH_DEVMODE}" = "1" ]; then
    load_modules "dev.d"
  fi
}

# Returns status 0 if the argument is a valid positive integer
# (i.e. it's not the null string, and contains only digits).
is_numeric() {
  ! echo "$1" | grep -qE '[^0-9]|^$'
}

# Prints the value corresponding to the passed-in field in the output from
# dump_power_status.
get_power_status_field() {
  local field="$1"
  dump_power_status | awk -v field="${field}" '$1 == field { print $2 }'
}

# Returns value of variable with given name.
expand_var() {
  local var="$1"
  eval echo "\"\$${var}\""
}

# Determine whether the variable is set in the environment.
var_is_set() {
  local var="$1"
  [ "$(expand_var "{${var}+set}")" = "set" ]
}

# shellcheck disable=SC2034
USAGE_help='[command]'
# shellcheck disable=SC2034
HELP_help='
  Display general help, or details for a specific command.
'
cmd_help() (
  local cmd

  case $# in
  0)
    help "missing parameter: command"
    return 1
    ;;
  1)
    # The ordering and relationship of variables here is subtle.
    # Consult README.md for more details.
    cmd="$1"
    if ! registered_crosh_command "${cmd}"; then
      echo "help: unknown command '${cmd}'"
      return 1
    elif ! check_command_available "${cmd}"; then
      echo "help: command '${cmd}' is not available"
      return 1
    else
      # If the command has a custom help func, call it.
      if registered_crosh_command_help "${cmd}"; then
        # Make sure the output is at least somewhat close to our standardized
        # form below.  We always want the program name first and a blank line
        # at the end.  This way `help_advanced` isn't completely ugly.
        echo "${cmd}"
        # The sed statement trims the first & last lines if they're blank.
        "help_${cmd}" | sed -e '1{/^$/d}' -e '${/^$/d}'
        echo

      elif var_is_set "USAGE_${cmd}"; then
        # Only show this function if the usage strings are actually set.
        local usage help
        usage="$(expand_var "USAGE_${cmd}")"
        help="$(expand_var "HELP_${cmd}")"
        printf '%s %s  %s\n\n' "${cmd}" "${usage}" "${help}"
      fi
    fi
    ;;
  *)
    help "too many arguments"
    return 1
    ;;
  esac
)

# Useful alias for commands to call us.
help() {
  if [ $# -ne 0 ]; then
    printf 'ERROR: %s\n\n' "$*"
  fi

  # This is set by `dispatch` when a valid command has been found.
  if [ -n "${CURRENT_COMMAND}" ]; then
    cmd_help "${CURRENT_COMMAND}"
  fi
}

# Check if a particular Chrome feature is enabled.
# Use the DBus method name as the parameter.
is_chrome_feature_enabled() {
  local method="$1"
  local reply status
  # shellcheck disable=SC2154
  reply="$(dbus-send --system --type=method_call --print-reply \
    --dest=org.chromium.ChromeFeaturesService \
    /org/chromium/ChromeFeaturesService \
    "org.chromium.ChromeFeaturesServiceInterface.${method}" \
    "string:${CROS_USER_ID_HASH}" 2>/dev/null)"
  status="$?"
  [ "${status}" -eq 0 ] && [ "${reply##* }" = "true" ]
}

# shellcheck disable=SC2034
USAGE_vsh='<vm_name> [<container_name>]'
# shellcheck disable=SC2034
HELP_vsh='
  Connect to a shell inside the VM <vm_name>, or to a shell inside the container
  <container_name> within the VM <vm_name>.
'
# shellcheck disable=SC2034
EXEC_vsh='/usr/bin/vsh'
cmd_vsh() (
  if ! is_chrome_feature_enabled "IsCrostiniEnabled" && \
     ! is_chrome_feature_enabled "IsBruschettaEnabled"; then
    echo "This command is not available."
    return 1
  fi

  if ! is_chrome_feature_enabled "IsVmManagementCliAllowed"; then
    echo "This command is disabled by your system administrator."
    return 1
  fi

  if [ $# -ne 1 ] && [ $# -ne 2 ]; then
    help "Missing vm_name"
    return 1
  fi

  local vm_name="$1"; shift
  if [ $# -eq 1 ]; then
    local container_name="$1"; shift
    vsh --vm_name="${vm_name}" --owner_id="${CROS_USER_ID_HASH}" \
      --target_container="${container_name}"
  else
    vsh --vm_name="${vm_name}" --owner_id="${CROS_USER_ID_HASH}" -- \
      LXD_DIR=/mnt/stateful/lxd \
      LXD_CONF=/mnt/stateful/lxd_conf
  fi

)

# swap_management is the helper function to send dbus message to
# swap_management. The first argument is the method name (e.g. SwapRestart),
# followed by method arguments if applicable.
swap_management() {
  # Default timeout 30 seconds.
  local timeout="--reply-timeout=30000"
  case $1 in
  --reply-timeout=*) timeout="$1"; shift;;
  esac
  local method="$1"; shift
  dbus-send "${timeout}" --system --print-reply --fixed \
      --dest=org.chromium.SwapManagement /org/chromium/SwapManagement \
      "org.chromium.SwapManagement.${method}" "$@"
}

# shellcheck disable=SC2034
USAGE_swap='[ enable <size (MB)> | disable | start | stop | status ]'
# shellcheck disable=SC2034
HELP_swap='
  Change kernel memory manager parameters
  (FOR EXPERIMENTS ONLY --- USE AT OWN RISK)

  "swap status" (also "swap" with no arguments) shows the values of various
  memory manager parameters and related statistics.

  The enable/disable options enable or disable compressed swap (zram)
  persistently across reboots, and take effect at the next boot.  The enable
  option takes the size of the swap area (in megabytes before compression).
  If the size is omitted, the factory default is chosen.

  The start/stop options turn swap on/off immediately, but leave the settings
  alone, so that the original behavior is restored at the next boot.

  WARNING: if swap is in use, turning it off can cause the system to
  temporarily hang while the kernel frees up memory.  This can take
  a long time to finish.
'
cmd_swap() (
  local cmd="${1:-}"
  shift

  # Check the usage first.
  case "${cmd}" in
  enable)
    if [ $# -gt 1 ]; then
      help "${cmd} takes only one optional argument"
      return 1
    fi
    ;;
  disable|start|stop|status|"")
    if [ $# -ne 0 ]; then
      help "${cmd} takes no arguments"
      return 1
    fi
    ;;
  *)
    help "unknown option: ${cmd}"
    return 1
    ;;
  esac

  # Then actually process the request.
  case "${cmd}" in
  "enable")
    local size="${1:-default}"
    if [ "${size}" = "default" ]; then
      size=0
    elif ! is_numeric "${size}"; then
      help "'${size}' is not a valid number"
      return 1
    fi
    swap_management SwapSetSize "int32:${size}"
    ;;
  "disable")
    swap_management SwapSetSize "int32:-1"
    ;;
  "start")
    swap_management SwapRestart
    ;;
  "stop")
    swap_management SwapStop
    ;;
  "status"|"")
    swap_management SwapStatus
    ;;
  esac
)

# shellcheck disable=SC2034
USAGE_time_info=''
# shellcheck disable=SC2034
HELP_time_info='
  Returns the current synchronization state for the time service.
'
cmd_time_info() (
  echo "Last time synchronization information:"
  dbus-send --system --type=method_call --print-reply \
      --dest=org.torproject.tlsdate /org/torproject/tlsdate \
      org.torproject.tlsdate.LastSyncInfo 2>/dev/null |
    sed -n \
        -e 's/boolean/network-synchronized:/p' \
        -e 's/string/last-source:/p' \
        -e 's/int64/last-synced-time:/p'
)

# shellcheck disable=SC2034
USAGE_cras='[ enable <flag> | disable <flag> | telephony <event> [arg] ]'
# shellcheck disable=SC2034
HELP_cras='
  Interact with CRAS(CrOS Audio Server) to set flags or trigger events.

  Subcommands:
    enable/disable <flag>:
      Enable or disable feature flag inside CRAS.
      Available flags:
      - wbs: Turn on this flag to make CRAS try to use wideband speech mode in
        Bluetooth HFP, if both the Bluetooth controller and peripheral supports
        this feature.
      - noise_cancellation: Turn on this flag to enable noise cancellation
        processing to input devices who support noise cancellation.

      Notice: The flag changes made through this command do not persist after
      reboot.

    telephony <event> [args...]:
      Trigger a telephony event pass to CRAS in Bluetooth HFP.

      Available events:
      - IncomingCall <PhoneNumber>: Make a call from external line.
          Ex: $ cras telephony IncomingCall 12345678
      - AnswerCall: Answer the call.
      - TerminateCall: Terminate the call.
      - SetDialNumber [DailNumber]: Set the last dialed number recorded. Clear
        the recorded number if no DailNumber is provided.
      - SetBatteryLevel <BatteryLevel>: Set and transfer the battery level to
        HF. The BatteryLevel should range from 0 to 5.
      - SetSignalStrength <SignalStrength>: Set and transfer the signal strength
        to HF. The SignalStrength should range from 0 to 5.
      - SetServiceAvailability <0/1>: Set if the service is available or not.
      - SetCallheld <CallHeldIndicator>: Set the callheld indicator.
        CallHeldIndicator:
          0 = No calls held
          1 = Call is placed on hold or active/held calls swapped
          (The AG has both an active AND a held call)
          2 = Call on hold, no active call
      - SetCallsetup <CallSetupIndicator>: Set the callsetup indicator.
        CallSetupIndicator:
          0 = No call setup in progress
          1 = Incoming call setup in progress
          2 = Outgoing call setup in dialing state
          3 = Outgoing call setup in alerting state
      - SetCall <CallIndicator>: Set the call indicator.
        CallIndicator:
          0 = No call (held or active)
          1 = Call is present (active or held)
'
cmd_cras() (
  if [ $# -eq 0 ]; then
    help "no subcommand specified"
    return 1
  fi

  local subcommand="$1"
  case "${subcommand}" in
  enable|disable|telephony) ;;
  *)
    help "unknown subcommand ${subcommand}"
    return 1
    ;;
  esac
  shift

  if [ "${subcommand}" = "enable" ] || [ "${subcommand}" = "disable" ]; then
    if [ $# -ne 1 ]; then
      help "missing or invalid arguments for enable/disable to set flag"
      return 1
    fi
    local enabled
    case "${subcommand}" in
    enable)
      enabled="true"
      ;;
    disable)
      enabled="false"
      ;;
    esac
    case "$1" in
    wbs)
      dbus-send --system --type=method_call --print-reply \
          --dest=org.chromium.cras /org/chromium/cras \
          org.chromium.cras.Control.SetWbsEnabled "boolean:${enabled}"
      return
      ;;
    noise_cancellation)
      dbus-send --system --type=method_call --print-reply \
          --dest=org.chromium.cras /org/chromium/cras \
          org.chromium.cras.Control.SetNoiseCancellationEnabled \
          "boolean:${enabled}"
      return
      ;;
    *)
      help "unknown flag $1"
      return 1
      ;;
    esac
  fi

  if [ "${subcommand}" = "telephony" ]; then
    if [ $# -eq 0 ]; then
      help "missing event"
      return 1
    fi

    local event="$1"; shift
    case "${event}" in
    SetDialNumber)
      if [ $# -gt 1 ]; then
        help "invalid arguments for ${subcommand} ${event}"
        return 1
      fi
      dbus-send --system --print-reply --type=method_call \
            --dest=org.chromium.cras /org/chromium/cras/telephony \
            "org.chromium.cras.Telephony.${event}" "string:$1"
      return
      ;;
    IncomingCall|SetBatteryLevel|SetSignalStrength|SetServiceAvailability| \
    SetCallheld|SetCallsetup|SetCall)
      local type
      if [ $# -ne 1 ]; then
        help "missing or invalid arguments for ${subcommand} ${event}"
        return 1
      fi
      case "${event}" in
      SetBatteryLevel|SetSignalStrength|SetServiceAvailability|SetCallheld| \
      SetCallsetup|SetCall)
        type="int32"
        ;;
      *)
        type="string"
        ;;
      esac
      dbus-send --system --print-reply --type=method_call \
            --dest=org.chromium.cras /org/chromium/cras/telephony \
            "org.chromium.cras.Telephony.${event}" "${type}:$1"
      return
      ;;
    AnswerCall|TerminateCall)
      if [ $# -ne 0 ]; then
        help "invalid arguments for ${subcommand} ${event}"
        return 1
      fi
      dbus-send --system --print-reply --type=method_call \
          --dest=org.chromium.cras /org/chromium/cras/telephony \
          "org.chromium.cras.Telephony.${event}"
      return
      ;;
    *)
      help "unknown event ${event}"
      return 1
      ;;
    esac
  fi
)

# Set the help string so crosh can discover us automatically.
# shellcheck disable=SC2034
HELP_ff_debug=''
# shellcheck disable=SC2034
EXEC_ff_debug='/usr/bin/ff_debug'
cmd_ff_debug() (
  debugd_shill ff_debug "$@"
)
help_ff_debug() (
  cmd_ff_debug --help
)

# shellcheck disable=SC2034
USAGE_set_arpgw='<true | false>'
# shellcheck disable=SC2034
HELP_set_arpgw='
  Turn on extra network state checking to make sure the default gateway
  is reachable.

  https://en.wikipedia.org/wiki/Default_gateway
'
cmd_set_arpgw() (
  debugd_shill set_arpgw "$@"
)

# shellcheck disable=SC2034
USAGE_set_wake_on_lan='<true | false>'
# shellcheck disable=SC2034
HELP_set_wake_on_lan='
  Enable or disable Wake on LAN for Ethernet devices.  This command takes
  effect after re-connecting to Ethernet and is not persistent across system
  restarts.
'
cmd_set_wake_on_lan() (
  debugd_shill set_wake_on_lan "$@"
)

# shellcheck disable=SC2034
USAGE_wifi_power_save='< status | enable | disable >'
# shellcheck disable=SC2034
HELP_wifi_power_save='
  Enable or disable WiFi power save mode.  This command is not persistent across
  system restarts.
'
cmd_wifi_power_save() (
  case "$1" in
    "status"|"")
      debugd GetWifiPowerSave
      ;;
    "enable")
      debugd SetWifiPowerSave "boolean:true"
      ;;
    "disable")
      debugd SetWifiPowerSave "boolean:false"
      ;;
    *)
      help "unknown option: $1"
      return 1
      ;;
  esac
)

debugd() {
  # Default timeout 30 seconds.
  local timeout="--reply-timeout=30000"
  case $1 in
  --reply-timeout=*) timeout="$1"; shift;;
  esac
  local method="$1"; shift
  dbus-send "${timeout}" --system --print-reply --fixed \
      --dest=org.chromium.debugd /org/chromium/debugd \
      "org.chromium.debugd.${method}" "$@"
}

# Run a debugd command for a long time and poll its output.
# This expects Start & Stop methods.
debugd_poll() (
  local methodbase="$1"; shift

  local pid fifo

  # Make sure we clean up the background process and temp files when the
  # user kills us with CTRL+C or CTRL+\.
  cleanup() {
    # Don't let the user kill us while cleaning up.
    trap : INT QUIT

    if [ -n "${pid}" ]; then
      if ! debugd "${methodbase}Stop" "string:${pid}"; then
        echo "warning: could not stop ${methodbase}"
      fi
      pid=''
    fi

    if [ -n "${fifo}" ]; then
      dir="$(dirname "${fifo}")"
      rm -rf "${dir}"
      fifo=''
    fi
  }
  trap cleanup INT QUIT

  if ! fifo="$(mk_fifo)"; then
    # The mk_fifo command already showed a warning.
    return 1
  fi
  { debugd "${methodbase}Start" "$@" >"${fifo}"; } 2>&1 &

  read -r pid < "${fifo}"

  # Background cat and block with `wait` to give debugd a chance to flush
  # output on trapped signal.
  cat "${fifo}" &
  wait $!

  cleanup
)

# Run a shill script via debugd.
debugd_shill() {
  local script="$1"; shift
  local args
  args="$(printf '%s,' "$@")"
  debugd_poll RunShillScript "fd:1" "string:${script}" "array:string:${args%,}"
}

# shellcheck disable=SC2034
USAGE_ping="[-4] [-6] [-c count] [-i interval] [-n] [-s packetsize] \
[-W waittime] <destination>"
# shellcheck disable=SC2034
HELP_ping='
  Send ICMP ECHO_REQUEST packets to a network host.  If <destination> is "gw"
  then the next hop gateway for the default route is used.
  Default is to use IPv4 [-4] rather than IPv6 [-6] addresses.

  https://en.wikipedia.org/wiki/Ping_(networking_utility)
'
# shellcheck disable=SC2030,SC2031
cmd_ping() (
  local option="dict:string:variant:"
  local ip_flag="-4"
  local dest

  while [ $# -gt 0 ]; do
    # Do just enough parsing to filter/map options; we
    # depend on ping to handle final validation.
    case "$1" in
    -4) option="${option}v6,boolean:false," ;;
    -6) ip_flag="-6"; option="${option}v6,boolean:true," ;;
    -i) shift; option="${option}interval,int32:$1," ;;
    -c) shift; option="${option}count,int32:$1," ;;
    -W) shift; option="${option}waittime,int32:$1," ;;
    -s) shift; option="${option}packetsize,int32:$1," ;;
    -n) option="${option}numeric,boolean:true," ;;
    -b) option="${option}broadcast,boolean:true," ;;
    -*)
      help "unknown option: $1"
      return 1
      ;;
    *)
      if [ "${dest+set}" = "set" ]; then
        help "too many destinations specified"
        return 1
      fi
      dest="$1"
      ;;
    esac

    shift
  done

  if [ "${dest+set}" != "set" ]; then
    help "missing parameter: destination"
    return 1
  fi

  # Convenient shorthand for the next-hop gateway attached to the
  # default route for the highest priority interface for that IP
  # version; this means if you have a host named "gw" then you'll need
  # to specify a FQDN or IP address.
  if [ "${dest}" = "gw" ]; then
    # The default route with the lowest metric represents the default
    # route for the primary device for that IP version.
    local metric main_route
    metric="$(ip "${ip_flag}" route show table 0 | \
        sed -nE 's/^default .* metric ([0-9]+).*/\1/p' | sort -n | head -n1)"
    main_route="$(ip "${ip_flag}" route show table 0 | \
        grep "^default .* metric ${metric} ")"
    dest="$(echo "${main_route}" | awk '{print $3}')"
    # Ping cannot handle link-local v6 addresses like v4 or global v6
    # addresses. It is necessary to provide ping with the format
    # ${addr}%${interface} OR -I ${interface} when that is the case.
    if [ "${ip_flag}" = "-6" ]; then
      local dev
      dev="$(echo "${main_route}" | awk '{print $5}')"
      option="${option}interface,string:${dev},"
    fi
    if [ -z "${dest}" ]; then
      echo "Cannot determine primary gateway; routing table is:"
      cmd_route
      return 1
    fi
  fi

  # Remove trailing comma in the options list if it exists.
  debugd_poll Ping "fd:1" "string:${dest}" "${option%,}"
)

# shellcheck disable=SC2034
USAGE_chaps_debug='[start|stop|<log_level>]'
# shellcheck disable=SC2034
HELP_chaps_debug='
  Sets the chapsd logging level.  No arguments will start verbose logging.
'
cmd_chaps_debug() (
  local level="${1:--2}"
  if [ "$1" = "stop" ]; then
    level=0
  fi
  if [ "$1" = "start" ]; then
    level=-2
  fi
  if chaps_client --set_log_level="${level}" 2>/dev/null; then
    echo "Logging level set to ${level}."
  else
    echo "Failed to set logging level."
  fi
)

# shellcheck disable=SC2034
USAGE_ipaddrs='[-4] [-6]'
# shellcheck disable=SC2034
HELP_ipaddrs='
  Display IP addresses.
  -4: Only show IPv4 addresses.
  -6: Only show IPv6 addresses.
'
cmd_ipaddrs() (
  local option="dict:string:variant:"
  local ipver=''

  while [ $# -gt 0 ]; do
    case $1 in
    -4) ipver=4;;
    -6) ipver=6;;
    *)
      help "unknown option: $1"
      return 1
    esac
    shift
  done

  if [ "${ipver:-4}" = "4" ]; then
    debugd GetIpAddresses "${option},v6,boolean:false"
  fi
  if [ -z "${ipver}" ]; then
    echo
  fi
  if [ "${ipver:-6}" = "6" ]; then
    debugd GetIpAddresses "${option},v6,boolean:true"
  fi
)

# shellcheck disable=SC2034
USAGE_route='[-4] [-6] [--all]'
# shellcheck disable=SC2034
HELP_route='
  Display the network routing tables.
  https://en.wikipedia.org/wiki/Routing_table

  -4: Only show IPv4 routes.
  -6: Only show IPv6 routes.
  --all: Show all routing tables.
'
# shellcheck disable=SC2120
cmd_route() (
  local option="dict:string:variant:"
  local ipver=''
  local show_all=false

  while [ $# -gt 0 ]; do
    case $1 in
    -4) ipver=4;;
    -6) ipver=6;;
    --all) show_all=true;;
    *)
      help "unknown option: $1"
      return 1
    esac
    shift
  done

  if [ "${ipver:-4}" = "4" ]; then
    debugd GetRoutes "${option},v6,boolean:false,all,boolean:${show_all}"
  fi
  if [ -z "${ipver}" ]; then
    echo
  fi
  if [ "${ipver:-6}" = "6" ]; then
    debugd GetRoutes "${option},v6,boolean:true,all,boolean:${show_all}"
  fi
)

# shellcheck disable=SC2034
USAGE_tracepath='[-4] [-6] [-n] <destination>[/port]'
# shellcheck disable=SC2034
HELP_tracepath='
  Trace the path/route to a network host.
  Default is to trace IPv4 [-4] rather than IPv6 [-6] targets.

  https://en.wikipedia.org/wiki/Traceroute
'
# shellcheck disable=SC2030,SC2031
cmd_tracepath() (
  local option="dict:string:variant:"
  local dest

  while [ $# -gt 0 ]; do
    # Do just enough parsing to filter/map options; we
    # depend on tracepath to handle final validation.
    case "$1" in
    -4) option="${option}v6,boolean:false," ;;
    -6) option="${option}v6,boolean:true," ;;
    -n) option="${option}numeric,boolean:true," ;;
    -*)
      help "unknown option: $1"
      return 1
      ;;
    *)
      if [ "${dest+set}" = "set" ]; then
        help "too many destinations specified"
        return 1
      fi
      dest="$1"
      ;;
    esac

    shift
  done

  if [ "${dest+set}" != "set" ]; then
    help "missing parameter: destination"
    return 1
  fi

  # Remove trailing comma in the options list if it exists.
  debugd_poll TracePath "fd:1" "string:${dest}" "${option%,}"
)

# shellcheck disable=SC2034
USAGE_modem='<command> [args...]'
# shellcheck disable=SC2034
HELP_modem='
  Interact with the 3G modem. Run "modem help" for detailed help.
'
cmd_modem() (
  debugd_shill modem "$@"
)

# shellcheck disable=SC2034
USAGE_autest='[--scheduled]'
# shellcheck disable=SC2034
HELP_autest='
  Trigger an auto-update against a **test** update server.

  WARNING: This may update to an untested version of ChromeOS which was never
  intended for end users!

  The --scheduled option fakes a scheduled update.
'
cmd_autest() (
  local omaha_url="autest"

  if [ "$1" = "--scheduled" ]; then
    # pretend that this is a scheduled check as opposed to an user-initiated
    # check for testing features that get enabled only on scheduled checks.
    omaha_url="autest-scheduled"
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      "--scheduled")
        omaha_url="autest-scheduled"
        ;;

      *)
        help "unknown option: $1"
        return 1
        ;;
    esac
    shift
  done

  echo "Calling update_engine_client with omaha_url = ${omaha_url}"
  /usr/bin/update_engine_client "--omaha_url=${omaha_url}"
)

# shellcheck disable=SC2034
USAGE_p2p_update='[enable|disable] [--num-connections] [--show-peers]'
# shellcheck disable=SC2034
HELP_p2p_update='
  Enables or disables the peer-to-peer (P2P) sharing of updates over the local
  network. This will both attempt to get updates from other peers in the
  network and share the downloaded updates with them. Run this command without
  arguments to see the current state.  Additional switches will display number
  of connections and P2P peers.
'
cmd_p2p_update() (

  if [ "$1" = "" ]; then
    /usr/bin/update_engine_client -show_p2p_update
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      "enable")
        /usr/bin/update_engine_client -p2p_update=yes -show_p2p_update
        ;;

      "disable")
        /usr/bin/update_engine_client -p2p_update=no -show_p2p_update
        ;;

      "--num-connections")
        if p2p_check_enabled; then
          echo "Number of active p2p connections:"
          /usr/sbin/p2p-client --num-connections
        fi
        ;;

      "--show-peers")
        if p2p_check_enabled; then
          echo "Current p2p peers:"
          /usr/sbin/p2p-client --list-all
        fi
        ;;

      *)
        help "unknown option: $1"
        return 1
        ;;
    esac

    shift
  done
)

p2p_check_enabled() {
  if ! /usr/bin/update_engine_client -show_p2p_update 2>&1 \
    | grep -q "ENABLED"; then
    echo "Run \"p2p_update enable\" to enable peer-to-peer before" \
    "using this command."
    return 1
  fi
}

# shellcheck disable=SC2034
USAGE_rlz='< status | enable | disable >'
# shellcheck disable=SC2034
HELP_rlz="
  Enable or disable RLZ.  See this site for details:
  http://dev.chromium.org/developers/design-documents/extensions/\
proposed-changes/apis-under-development/rlz-api
"
cmd_rlz() (
  local flag_file="${HOME}/.rlz_disabled"
  local enabled=1
  local changed=0
  if [ -r "${flag_file}" ]; then
    enabled=0
  fi
  case "$1" in
    "status")
      if [ "${enabled}" -eq 1 ]; then
        echo "Currently enabled"
      else
        echo "Currently disabled"
      fi
      return
      ;;

    "enable")
      if [ "${enabled}" -eq 0 ]; then
        changed=1
      fi
      rm -f "${flag_file}"
      ;;

    "disable")
      if [ "${enabled}" -eq 1 ]; then
        changed=1
      fi
      touch "${flag_file}"
      ;;

    *)
      help "unknown option: $1"
      return 1
      ;;
  esac
  if [ "${changed}" -eq 1 ]; then
    echo "You must reboot for this to take effect."
  else
    echo "No change."
  fi
)

mk_fifo() {
  local dir fifo

  # We want C-c to terminate the running test so that the UI stays the same.
  # Therefore, create a fifo to direct the output of the test to, and have a
  # subshell read from the fifo and emit to stdout. When the subshell ends (at a
  # C-c), we stop the test and clean up the fifo.
  # no way to mktemp a fifo, so make a dir to hold it instead
  if ! dir="$(mktemp -d "/tmp/crosh-test-XXXXXXXXXX")"; then
    echo "Can't create temporary directory"
    return 1
  fi
  fifo="${dir}/fifo"
  if ! mkfifo "${fifo}"; then
    echo "Can't create fifo at ${fifo}"
    return 1
  fi

  echo "${fifo}"
}

# shellcheck disable=SC2034
USAGE_storage_test_1=''
# shellcheck disable=SC2034
HELP_storage_test_1='
  Performs a short offline SMART test.
'
cmd_storage_test_1() (
  option="$1"

  debugd Smartctl "string:abort_test" >/dev/null

  test="$(debugd Smartctl "string:short_test")"
  if [ "${option}" != "-v" ]; then
    echo "${test}" | sed -n '1p;2p'
    echo ""
    echo "${test}" | grep "Please wait"
  else
    echo "${test}"
  fi

  echo ""

  while debugd Smartctl "string:capabilities" |
        grep -q "of test remaining"; do
    true
  done

  result="$(debugd Smartctl "string:selftest")"
  if [ "${option}" != "-v" ]; then
    echo "${result}" | grep -e "Num" -e "# 1"
  else
    echo "${result}"
  fi

  debugd Smartctl "string:abort_test" >/dev/null
)

# shellcheck disable=SC2034
USAGE_storage_test_2=''
# shellcheck disable=SC2034
HELP_storage_test_2='
  Performs an extensive readability test.
'
cmd_storage_test_2() (
  debugd_poll Badblocks "fd:1"
)

# shellcheck disable=SC2034
USAGE_memory_test=''
# shellcheck disable=SC2034
HELP_memory_test='
  Performs extensive memory testing on the available free memory.
'
cmd_memory_test() (
  # Getting total free memory in KB.
  local mem
  mem="$(grep MemFree /proc/meminfo | tr -s " " | cut -d" " -f 2)"

  # Converting to MiB.
  mem="$((mem / 1024))"

  # Giving OS 200MB free memory before hogging the rest of it.
  mem="$((mem - 200))"

  debugd_poll Memtester "fd:1" "uint32:${mem}"
)

# shellcheck disable=SC2034
USAGE_battery_firmware='<info>'
# shellcheck disable=SC2034
HELP_battery_firmware='
  info   : Query battery info.
'
cmd_battery_firmware() (
  option="$1"
  case "${option}" in
    info)
      debugd --reply-timeout=$(( 10 * 60 * 1000 )) BatteryFirmware "string:${option}"
      echo ""
      ;;
    *)
      help "Unknown option: ${option}"
      ;;
  esac
)

# shellcheck disable=SC2034
USAGE_battery_test='[<test length>]'
# shellcheck disable=SC2034
HELP_battery_test='
  Tests battery discharge rate for given number of seconds. Without an argument,
  defaults to 300 seconds.
'
cmd_battery_test() (
  local test_length="$1"
  if [ -z "${test_length}" ]; then
    echo "No test length specified. Defaulting to 300 seconds."
    test_length=300
  fi

  if ! check_digits "${test_length}"; then
    echo "Invalid test length."
    return 1
  fi

  if [ "$(get_power_status_field 'battery_present')" != '1' ]; then
    echo "No battery found."
    return 1
  fi

  if [ "$(get_power_status_field 'battery_discharging')" = '1' ]; then
    local bat_status='discharging'
    local bat_discharging=1
  else
    local bat_status='charging or full'
    local bat_discharging=0
  fi

  local bat_pct bat_full bat_full_design bat_health
  bat_pct="$(get_power_status_field 'battery_percent')"
  bat_full="$(get_power_status_field 'battery_charge_full')"
  bat_full_design="$(get_power_status_field 'battery_charge_full_design')"
  bat_health="$(echo "${bat_full}" "${bat_full_design}" | \
      awk '{ printf "%.2f", 100.0 * $1 / $2 }')"

  echo "Battery is ${bat_status} (${bat_pct}% left)"
  echo "Battery health: ${bat_health}%"

  if [ "${bat_discharging}" != '1' ]; then
    echo "Please make sure the power supply is unplugged and retry the test."
    return 1
  fi

  echo "Please wait..."
  sleep "${test_length}"

  local bat_after bat_diff
  bat_after="$(get_power_status_field 'battery_percent')"
  bat_diff="$(echo "${bat_pct}" "${bat_after}" | \
      awk '{ printf "%.2f", $1 - $2 }')"
  echo "Battery discharged ${bat_diff}% in ${test_length} second(s)."
)

# Set the help string so crosh can discover us automatically.
# shellcheck disable=SC2034
HELP_diag=''
# shellcheck disable=SC2034
EXEC_diag='/usr/bin/cros-health-tool'
cmd_diag() (
  # diag does its own parameter validation. Aside from a single D-Bus command to
  # bootstrap a mojo connection to cros_healthd, diag only sends mojo commands
  # and does no work itself.
  local action="$1"
  shift
  if [ "${action}" = "list" ]; then
    cros-health-tool diag "get_routines"
  else
    # Aside listing available routines, the only other valid option is running a
    # routine. This is a safe assumption to make, because diag will validate the
    # --routine flag and fail on any invalid routines.
    cros-health-tool diag "${action}" "$@"
  fi
)
help_diag() (
  cros-health-tool diag "--crosh_help"
)

# shellcheck disable=SC2034
USAGE_enroll_status='[--mode] [--domain] [--realm] [--user]'
# shellcheck disable=SC2034
HELP_enroll_status='
  Displays device enrollment information.
'
cmd_enroll_status() (
  if [ "$1" = "" ]; then
    if check_enterprise_mode; then
      echo "Enrollment mode:"
      /usr/sbin/device_management_client --action=install_attributes_get \
        --name=enterprise.mode
    else
      echo "This device is not enterprise enrolled."
    fi
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      "--mode")
        if check_enterprise_mode; then
          echo "Enrollment mode:"
          /usr/sbin/device_management_client --action=install_attributes_get \
            --name=enterprise.mode
        else
          echo "This device is not enterprise enrolled."
        fi
        ;;

      "--domain")
        if check_enterprise_mode; then
          echo "Enrollment domain:"
          /usr/sbin/device_management_client --action=install_attributes_get \
            --name=enterprise.domain
        else
          echo "Enterprise enrollment domain not found."
        fi
        ;;

      "--realm")
        if check_enterprise_mode; then
          echo "Enrollment realm:"
          /usr/sbin/device_management_client --action=install_attributes_get \
            --name=enterprise.realm
        else
          echo "Enterprise enrollment realm not found."
        fi
        ;;

      "--user")
        if check_enterprise_mode; then
          echo "Enrollment user:"
          /usr/sbin/device_management_client --action=install_attributes_get \
            --name=enterprise.user
        else
          echo "Enterprise enrollment user not found."
        fi
        ;;

      *)
        help "unknown option: $1"
        return 1
        ;;
    esac

    shift
  done
)

check_enterprise_mode() {
  if ! /usr/sbin/device_management_client --action=install_attributes_get \
      --name=enterprise.mode 2>&1 | grep -q "enterprise"; then
    return 1
  fi
}

# shellcheck disable=SC2034
USAGE_gesture_prop="[ devices | list <device ID> \
| get <device ID> <property name> | set <device ID> <property name> <value> ]"
# shellcheck disable=SC2034
HELP_gesture_prop='
  Read and change gesture properties for attached input devices. The "Enable
  gesture properties D-Bus service" flag must be enabled for this command to
  work.

  For more details, see:
  https://chromium.googlesource.com/chromiumos/platform/gestures/+/HEAD/docs/gesture_properties.md

  Subcommands:
    devices, devs:
      List the devices managed by the gestures library, with their numeric IDs.

    list <device ID>:
      List the properties for the device with the given ID.

    get <device ID> <property name>:
      Get the current value of a property. Property names containing spaces
      should be quoted. For example:
      $ gesture_prop get 12 "Mouse CPI"

    set <device ID> <property name> <value>:
      Set the value of a property. Values use the same syntax as dbus-send
      (https://dbus.freedesktop.org/doc/dbus-send.1.html#description), and
      should either be arrays or strings. For example:
      $ gesture_prop set 12 "Mouse CPI" array:double:500
      $ gesture_prop set 12 "Log Path" string:/tmp/foo.txt
'
cmd_gesture_prop() (
  local subcommand="$1"
  if [ $# -eq 0 ]; then
    help "no subcommand specified"
    return 1
  fi
  case "${subcommand}" in
  devices|devs|list|get|set) ;;
  *)
    help "invalid subcommand ${subcommand}"
    return 1
    ;;
  esac
  shift

  if [ "${subcommand}" = "devices" ] || [ "${subcommand}" = "devs" ]; then
    if [ $# -ne 0 ]; then
      help "too many arguments for 'devices' subcommand"
      return 1
    fi
    dbus-send --print-reply --system \
      --dest=org.chromium.GesturePropertiesService \
      /org/chromium/GesturePropertiesService \
      org.chromium.GesturePropertiesServiceInterface.ListDevices
    return
  fi

  local device_id="$1"
  if [ -z "${device_id}" ]; then
    help "missing parameter: device ID"
    return 1
  elif ! is_numeric "${device_id}"; then
    help "invalid device ID (must be a number)"
    return 1
  fi
  shift

  if [ "${subcommand}" = "list" ]; then
    dbus-send --print-reply --system \
      --dest=org.chromium.GesturePropertiesService \
      /org/chromium/GesturePropertiesService \
      org.chromium.GesturePropertiesServiceInterface.ListProperties \
      int32:"${device_id}"
    return
  fi

  # All property names contain spaces, so we need to quote them, but quotes were
  # not taken into account when splitting the command arguments, so treat the
  # remaining arguments as one string and split by the quotes.
  local property_name
  local value
  local remaining_args="$*"
  local first_char
  first_char="$(substr "${remaining_args}" "0" "2")"
  if [ "${first_char}" != '"' ] && [ "${first_char}" != "'" ]; then
    property_name=$1
    value=$2
  else
    local args_without_quote quote_2_pos
    args_without_quote="$(substr "${remaining_args}" "1")"
    # shellcheck disable=SC2003,SC2308
    quote_2_pos="$(expr index "${args_without_quote}" "${first_char}")"
    property_name="$(substr "${args_without_quote}" "0" "${quote_2_pos}")"
    # $value will have the quote and a space at the front, so trim that.
    value="$(substr "${remaining_args}" "$((quote_2_pos + 2))")"
  fi

  case "${subcommand}" in
  get)
    if [ -n "${value}" ]; then
      help "too many arguments for 'get' subcommand"
      return 1
    fi
    dbus-send --print-reply --system \
      --dest=org.chromium.GesturePropertiesService \
      /org/chromium/GesturePropertiesService \
      org.chromium.GesturePropertiesServiceInterface.GetProperty \
      int32:"${device_id}" string:"${property_name}"
    return
    ;;
  set)
    dbus-send --print-reply --system \
      --dest=org.chromium.GesturePropertiesService \
      /org/chromium/GesturePropertiesService \
      org.chromium.GesturePropertiesServiceInterface.SetProperty \
      int32:"${device_id}" string:"${property_name}" "${value}"
    return
    ;;
  esac
)

substr() {
  local str="$1"
  local start="$2"
  local end="$3"

  : $(( start += 1 ))

  if [ -n "${end}" ]; then
    : $(( end -= 1 ))
  fi

  printf '%s' "${str}" | cut -c"${start}-${end}"
}

# Return true if the arg is a shell function.
is_shell_function() {
  local func="$1"
  type "${func}" 2>/dev/null | head -1 | grep -q 'function'
}

# Return true if the first arg is a valid crosh command.
registered_crosh_command() {
  local command="$1"
  is_shell_function "cmd_${command}"
}

# Return true if the specified command has a custom help function.
registered_crosh_command_help() {
  local command="$1"
  is_shell_function "help_${command}"
}

# Return true if the first arg is a command available on
# the system. We assume that all commands that do not
# define EXEC_<command> variable are always available. For
# commands that do define EXEC_<command> variable, we
# ensure that it contains name of a valid shell command.
check_command_available() {
  local exec
  exec="$(expand_var "EXEC_$1")"
  [ -z "${exec}" ] || command -v "${exec}" >/dev/null
}

# Run a command with its args as an array.
dispatch() {
  local command="$1"
  shift
  local p

  if ! registered_crosh_command "${command}"; then
    help "unknown command: ${command}"
  elif ! check_command_available "${command}"; then
    help "command '${command}' is not available"
  else
    # See if --help was requested; if so, handle it directly so each command
    # doesn't have to deal with it directly.
    for p in "$@"; do
      if [ "${p}" = "-h" ] || [ "${p}" = "--help" ]; then
        cmd_help "${command}"
        return 0
      fi
    done

    # Set CURRENT_COMMAND for the `help` helper.
    CURRENT_COMMAND="${command}" "cmd_${command}" "$@"
  fi
}

usage() {
  if [ $# -gt 0 ]; then
    echo "ERROR: $*" >&2
  fi
  exit 1
}

main() {
  # If we aren't installed, use local files for testing.
  if [ ! -d "${CROSH_MODPATH}" ]; then
    CROSH_MODPATH="$(dirname "$0")"
    echo "Loading from local paths instead: ${CROSH_MODPATH}"
  fi

  while [ $# -gt 0 ]; do
    case $1 in
    --dev)
      CROSH_DEVMODE="1"
      ;;
    --no-dev)
      CROSH_DEVMODE="0"
      ;;
    --removable|--usb)
      CROSH_REMOVABLE="1"
      ;;
    --no-usb)
      CROSH_REMOVABLE="0"
      ;;
    --)
      CROSH_SINGLE_COMMAND=1
      shift
      break
      ;;
    *)
      usage "Unknown option: $1"
      ;;
    esac
    shift
  done

  load_extra_crosh

  if [ -z "${CROSH_DEVMODE}" ]; then
    usage "--dev or --no-dev is required."
  fi
  if [ -z "${CROSH_REMOVABLE}" ]; then
    usage "--usb or --no-usb is required."
  fi
  if [ "${CROSH_SINGLE_COMMAND}" != "1" ]; then
    usage "Interactive mode no longer supported."
  fi

  dispatch "$@"
  exit $?
}
main "$@"
