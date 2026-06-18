# /etc/skel/.bashrc
#
# This file is sourced by all *interactive* bash shells on startup,
# including some apparently interactive shells such as scp and rcp
# that can't tolerate any output.  So make sure this doesn't display
# anything or bad things will happen !
# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* ]] ; then
  # Shell is non-interactive.  Be done now!
  return
fi
source /etc/profile # emerge breaks without this
# Put your fun stuff here.
export gitHelpers="/usr/local/libexec/git-core"
case ":$PATH:" in
  *":$gitHelpers:"*) ;;
  *) export PATH="$gitHelpers:$PATH" ;;
esac


if [[ -d /usr/local/nix/store ]]; then
  if ! mountpoint -q /nix; then
    mkdir -p /nix
    mount --bind /usr/local/nix /nix
  fi
  source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  unset LD_LIBRARY_PATH
fi

pid=$PPID
ggpid=$(awk '/PPid:/{print $2}' /proc/$(awk '/PPid:/{print $2}' /proc/$PPID/status 2>/dev/null)/status 2>/dev/null)
if [ "$(cat /proc/$ggpid/comm 2>/dev/null)" = "crosh.old" ]; then 
  login
  return 0
fi
