#!/usr/bin/env bats
# Tests for the pure/testable logic in mod-files/usr/lib/libmosh.sh.
#
# libmosh.sh is written to run on a real Modmium device (it sources
# /usr/share/misc/shflags, reads /.branch, /usr/share/.version, etc, none of
# which exist here), but none of that is fatal to source it - bash just
# prints "No such file" warnings and leaves the corresponding variables
# empty, so the actual functions we care about testing still load fine.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  # The full_menu/selector dispatch tests below exercise real vt-mosh.sh-style
  # scripts, which end with `tput cnorm`. Many non-interactive shells default
  # $TERM to "dumb", which has no cursor-control capabilities, so tput fails
  # there; since these tests don't wrap the call in bats' `run`, that failure
  # gets misread as the dispatch itself failing. Force a real terminfo entry
  # so the tests reflect dispatch behavior only, regardless of what $TERM the
  # shell running bats happened to inherit.
  export TERM=xterm
  # libmosh.sh reads a few device-only files at the top (stateful, /.branch,
  # /usr/share/misc/shflags, ...) that don't exist off-device; those failures
  # are harmless (the corresponding variables just end up empty) but bats
  # runs under errexit, so swallow them explicitly rather than aborting.
  source "$ROOT_DIR/mod-files/usr/lib/libmosh.sh" 2>/dev/null || true

  # Route the shared log to a scratch file instead of the real (root-owned,
  # ChromeOS-only) stateful partition path.
  MODMIUM_LOG="$BATS_TEST_TMPDIR/modmium.log"
  DEVINSTALL_MARKER="$BATS_TEST_TMPDIR/.devinstall_complete"
}

# -- opposite_num --

@test "opposite_num maps kernel/root partition numbers to their pair" {
  [[ "$(opposite_num 2)" == "4" ]]
  [[ "$(opposite_num 4)" == "2" ]]
  [[ "$(opposite_num 3)" == "5" ]]
  [[ "$(opposite_num 5)" == "3" ]]
}

@test "opposite_num returns 'skid' for anything else" {
  [[ "$(opposite_num 99)" == "skid" ]]
  [[ "$(opposite_num "")" == "skid" ]]
}

# -- format_part_number --

@test "format_part_number adds a 'p' separator only when the disk name ends in a digit" {
  [[ "$(format_part_number /dev/sda 1)" == "/dev/sda1" ]]
  [[ "$(format_part_number /dev/mmcblk0 1)" == "/dev/mmcblk0p1" ]]
  [[ "$(format_part_number /dev/nvme0n1 3)" == "/dev/nvme0n1p3" ]]
}

# -- confirm_destructive --

@test "confirm_destructive succeeds on y/Y and fails on anything else (default: no)" {
  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_destructive "test" <<< "y"'
  [ "$status" -eq 0 ]

  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_destructive "test" <<< "Y"'
  [ "$status" -eq 0 ]

  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_destructive "test" <<< "n"'
  [ "$status" -eq 1 ]

  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_destructive "test" <<< ""'
  [ "$status" -eq 1 ]
}

# -- confirm_irreversible --

@test "confirm_irreversible only succeeds on a literal double 'yy'" {
  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_irreversible "test" <<< "yy"'
  [ "$status" -eq 0 ]

  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_irreversible "test" <<< "y"'
  [ "$status" -eq 1 ]

  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; confirm_irreversible "test" <<< "no"'
  [ "$status" -eq 1 ]
}

# -- run_with_feedback --

@test "run_with_feedback passes through the wrapped command's exit status" {
  run run_with_feedback "msg" true
  [ "$status" -eq 0 ]

  run run_with_feedback "msg" false
  [ "$status" -eq 1 ]

  run run_with_feedback "msg" bash -c 'exit 7'
  [ "$status" -eq 7 ]
}

@test "run_with_feedback reports both the message and success/failure" {
  run run_with_feedback "doing the thing" true
  [[ "$output" == *"doing the thing"* ]]
  [[ "$output" == *"Done."* ]]

  run run_with_feedback "doing the thing" false
  [[ "$output" == *"failed"* ]]
}

# -- log_action / fail logging --

@test "log_action appends a timestamped line to MODMIUM_LOG" {
  log_action "hello world"
  [ -f "$MODMIUM_LOG" ]
  grep -q "hello world" "$MODMIUM_LOG"
}

@test "confirm_destructive logs whether it was confirmed or declined" {
  confirm_destructive "do the thing" <<< "y" || true
  grep -q "CONFIRMED: do the thing" "$MODMIUM_LOG"

  confirm_destructive "do the thing" <<< "n" || true
  grep -q "DECLINED: do the thing" "$MODMIUM_LOG"
}

@test "fail logs, prints the message, and exits non-zero" {
  run bash -c 'source "'"$ROOT_DIR"'/mod-files/usr/lib/libmosh.sh" 2>/dev/null; MODMIUM_LOG="'"$MODMIUM_LOG"'"; fail "boom"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
  grep -q "FAILED: boom" "$MODMIUM_LOG"
}

# -- ensure_deps gating logic (dev_install/emerge/ldconfig stubbed out) --

setup_ensure_deps_stubs() {
  dev_install() { return 0; }
  emerge() { return 0; }
  ldconfig() { return 0; }
}

@test "ensure_deps bootstraps dev packages only once, then just emerges" {
  setup_ensure_deps_stubs
  # ensure_deps runs the dev_install step inside a nested `bash -c` (to
  # support piping answers into it), so the stub needs to be exported for
  # that child shell to see it.
  export DEV_INSTALL_CALLS="$BATS_TEST_TMPDIR/dev_install_calls"
  : > "$DEV_INSTALL_CALLS"
  dev_install() { echo called >> "$DEV_INSTALL_CALLS"; return 0; }
  export -f dev_install

  [ ! -f "$DEVINSTALL_MARKER" ]
  ensure_deps somepkg
  [ -f "$DEVINSTALL_MARKER" ]
  [ "$(wc -l < "$DEV_INSTALL_CALLS")" -eq 1 ]

  ensure_deps somepkg
  [ "$(wc -l < "$DEV_INSTALL_CALLS")" -eq 1 ] # not called again, marker already present
}

@test "ensure_deps fails cleanly if dev_install fails" {
  setup_ensure_deps_stubs
  dev_install() { return 1; }
  export -f dev_install

  run ensure_deps somepkg
  [ "$status" -ne 0 ]
  [ ! -f "$DEVINSTALL_MARKER" ]
}

@test "ensure_deps fails cleanly if emerge fails" {
  setup_ensure_deps_stubs
  emerge() { return 1; }

  run ensure_deps somepkg
  [ "$status" -ne 0 ]
}

# -- full_menu/selector dispatch --
#
# Regression test for a real bug found while auditing the menu scripts:
# full_menu() already calls selector() itself once its input loop breaks on
# Enter, so a script whose *own* bottom section calls `full_menu` and then
# *also* calls `selector` again ends up dispatching the selected action
# twice for any handler that returns normally (doesn't exit or loop back
# into its own menu_reset+full_menu). Confirmed by reproducing it against
# the pre-fix pattern before removing the redundant trailing `selector`
# calls from every mod-files script that had it (except cr3nroll.sh, which
# is vendored from a separate project and manages its own menu loop).

@test "a selected action fires exactly once when the script only calls full_menu (not also selector)" {
  cat > "$BATS_TEST_TMPDIR/menu.sh" <<EOF
source "$ROOT_DIR/mod-files/usr/lib/libmosh.sh" 2>/dev/null
counter="$BATS_TEST_TMPDIR/counter"
: > "\$counter"
doThing(){ echo called >> "\$counter"; }
menu_reset(){ options=("Do Thing" "Exit"); functions=("doThing" "quit"); num_options=\${#options[@]}; menuText=""; }
menu_reset
clear
full_menu
tput cnorm
EOF
  printf '\r' | timeout 3 bash "$BATS_TEST_TMPDIR/menu.sh" >/dev/null 2>&1
  [ "$(wc -l < "$BATS_TEST_TMPDIR/counter")" -eq 1 ]
}

@test "(documents the bug) an extra trailing selector call double-dispatches the same action" {
  cat > "$BATS_TEST_TMPDIR/menu_buggy.sh" <<EOF
source "$ROOT_DIR/mod-files/usr/lib/libmosh.sh" 2>/dev/null
counter="$BATS_TEST_TMPDIR/counter_buggy"
: > "\$counter"
doThing(){ echo called >> "\$counter"; }
menu_reset(){ options=("Do Thing" "Exit"); functions=("doThing" "quit"); num_options=\${#options[@]}; menuText=""; }
menu_reset
clear
full_menu
tput cnorm
selector
EOF
  printf '\r' | timeout 3 bash "$BATS_TEST_TMPDIR/menu_buggy.sh" >/dev/null 2>&1
  [ "$(wc -l < "$BATS_TEST_TMPDIR/counter_buggy")" -eq 2 ]
}

@test "no mod-files script (other than the vendored cr3nroll.sh) ends with a redundant selector call" {
  offenders=""
  for f in "$ROOT_DIR"/mod-files/usr/bin/*.sh; do
    [[ "$(basename "$f")" == "cr3nroll.sh" ]] && continue
    if [[ "$(tail -n1 "$f")" == "selector" ]] && grep -qE '^\s*full_menu\s*$' "$f"; then
      offenders="$offenders $f"
    fi
  done
  [ -z "$offenders" ]
}
