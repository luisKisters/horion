#!/bin/bash
# Tests what the tours cannot reach, with real key presses: the two global shortcuts and the real menu bar menu.
# It starts the built app on demo data, presses keys through cua-driver, looks at the app's windows from outside
# the app, and quits it. Takes about a minute.
#
# The keys go to the real desktop: Horion's window and menu appear on this Mac's screen while it runs.
# It stops at the first failed check, so that no further key reaches another app.
# An installed Horion (/Applications) is quit first and started again at the end, because two Horions would both
# answer the same shortcut. Any other running Horion stops the run.
# No screenshot is taken: a picture of the desktop shows whatever else is open.
#
# Usage: scripts/cua-check.sh [--skip-build]
# Exit: 0 all checks passed, 1 a check failed, 2 it could not run (build failed, another Horion or another
#       cua-check is running), 3 cua-driver is not set up on this Mac (say so in the PR).
# Set up once per Mac: install cua-driver (https://cua.ai/docs/cua-driver/quickstart), then `cua-driver permissions grant`.
#
# To add a check: press keys with gkey (a system-wide shortcut) or tkey (a key for Horion only), then call expect.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

command -v cua-driver >/dev/null || { echo "cua-driver is not installed on this Mac"; exit 3; }
[ "$(cua-driver permissions status 2>/dev/null | grep -c '✅ on')" -ge 2 ] \
  || { echo "cua-driver lacks Accessibility or Screen Recording: run cua-driver permissions grant"; exit 3; }
if ! cua-driver status >/dev/null 2>&1; then
  (cua-driver serve >/dev/null 2>&1 &)
  for _ in $(seq 20); do cua-driver status >/dev/null 2>&1 && break; sleep 0.5; done
  cua-driver status >/dev/null 2>&1 || { echo "the cua-driver daemon does not start"; exit 3; }
fi

# One run at a time on this Mac, across all worktrees. A lock whose run is dead is taken over.
LOCK=/tmp/horion-cua-check.lock
if ! mkdir "$LOCK" 2>/dev/null; then
  if kill -0 "$(cat "$LOCK/pid" 2>/dev/null)" 2>/dev/null; then echo "another cua-check is running"; exit 2; fi
fi
echo $$ > "$LOCK/pid"

STATE=artifacts/tmp/app-state
PID=""; REOPEN=0
cleanup() {
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null
    for _ in $(seq 20); do kill -0 "$PID" 2>/dev/null || break; sleep 0.25; done   # gone before the installed one takes the keys
  fi
  [ $REOPEN -eq 1 ] && open -g /Applications/Horion.app
  rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 2' INT TERM

mkdir -p artifacts/tmp
if [ "${1:-}" != "--skip-build" ]; then
  scripts/build-app.sh > artifacts/tmp/cua-build.log 2>&1 || { tail -20 artifacts/tmp/cua-build.log; echo "the build failed"; exit 2; }
fi
[ -d build/Horion.app ] || { echo "build/Horion.app not found: run without --skip-build"; exit 2; }
BIN="$(cd build/Horion.app && pwd -P)/Contents/MacOS/Horion"
swiftc -O scripts/app-state.swift -o "$STATE" || { echo "scripts/app-state.swift does not compile"; exit 2; }

for other in $(pgrep -f 'Horion.app/Contents/MacOS/Horion'); do
  if ps -o command= -p "$other" | grep -q '^/Applications/Horion.app/'; then
    echo "quitting the installed Horion for the test, it starts again at the end"
    REOPEN=1; "$STATE" quit "$other"
    for _ in $(seq 20); do kill -0 "$other" 2>/dev/null || break; sleep 0.25; done
  fi
done
if pgrep -fl 'Horion.app/Contents/MacOS/Horion'; then
  echo "another Horion is still running (above). It would answer the same shortcuts: quit it, or run this later."
  exit 2
fi

cua() { perl -e 'alarm shift; exec @ARGV' 40 cua-driver call "$@"; }
windows_json() { cua list_windows "{\"pid\":$PID}"; }
# How many normal windows Horion has, on screen or not. More than one is the "second window" bug.
windows() { windows_json | python3 -c "import sys,json; print(sum(1 for w in json.load(sys.stdin)['windows'] if w['layer']==0))"; }
window_id() { windows_json | python3 -c "import sys,json; print(next(w['window_id'] for w in json.load(sys.stdin)['windows'] if w['layer']==0))"; }
# gkey: a system-wide key press, as from the keyboard. tkey: a key press sent to Horion only, never to another app.
gkey() { cua hotkey "{\"keys\":[$1],\"scope\":\"desktop\"}" >/dev/null || { echo "FAIL  cua could not press $1"; exit 1; }; sleep 1.5; }
tkey() { cua hotkey "{\"keys\":[$1],\"pid\":$PID,\"window_id\":$(window_id)}" >/dev/null || { echo "FAIL  cua could not press $1"; exit 1; }; sleep 1.5; }
APP_KEY='"ctrl","cmd","r"'; MENU_KEY='"ctrl","cmd","e"'   # the defaults in GlobalShortcut.swift
# expect "<what>" "<part of the state line>"...: passes when every part is in the state line. The first failure ends the run.
expect() {
  local what="$1" s; shift
  s="$("$STATE" state "$PID") windows=$(windows)"
  for want in "$@"; do
    case " $s " in *" $want "*) ;; *) echo "FAIL  $what   (wanted $want, got: $s)"; exit 1 ;; esac
  done
  echo "ok    $what"
}

"$BIN" --demo >/dev/null 2>&1 &
PID=$!
for _ in $(seq 40); do "$STATE" state "$PID" 2>/dev/null | grep -q "window=1" && break; sleep 0.5; done
sleep 1

echo "== the app key: $APP_KEY"
expect "starts in front with one window" hidden=0 active=1 window=1 windows=1
gkey "$APP_KEY";  expect "in front: the key hides it" hidden=1 window=0 windows=1
gkey "$APP_KEY";  expect "hidden: the key shows it" hidden=0 active=1 window=1 windows=1
tkey '"cmd","m"'; expect "⌘M minimises it" window=0
gkey "$APP_KEY";  expect "minimised: the key brings the window back, still one" hidden=0 window=1 windows=1
tkey '"cmd","w"'; expect "⌘W closes it" window=0
gkey "$APP_KEY";  expect "closed: the key opens one window again" hidden=0 window=1 windows=1
"$STATE" hide "$PID"; sleep 1.5; expect "hidden with ⌘H" hidden=1 window=0
gkey "$APP_KEY";  expect "hidden with ⌘H: the key shows it, still one window" hidden=0 window=1 windows=1
PRESS="{\"tool\":\"hotkey\",\"args\":{\"keys\":[$APP_KEY],\"scope\":\"desktop\",\"post_action_wait\":\"none\"}}"
cua run_steps "{\"steps\":[$PRESS,$PRESS,$PRESS]}" | grep -q '"ok": *true' || { echo "FAIL  cua could not send three quick presses"; exit 1; }
sleep 1.5;        expect "three quick presses: each one counts, so it ends hidden" hidden=1 window=0 windows=1

echo "== the menu key: $MENU_KEY"
gkey "$MENU_KEY"; expect "Horion hidden: the key opens the menu bar menu" menu=1
gkey "$MENU_KEY"; expect "the key closes the open menu" menu=0
sleep 2;          expect "and it stays closed" menu=0
gkey "$APP_KEY";  expect "the app key shows the window again" hidden=0 window=1 windows=1
gkey "$MENU_KEY"; expect "Horion in front: the key opens the menu" menu=1
cua press_key '{"key":"escape","scope":"desktop"}' >/dev/null; sleep 1.5   # the menu is open (checked above), so Escape goes to it
expect "Escape closes it" menu=0
sleep 2;          expect "and it stays closed" menu=0

echo "cua-check: all checks passed"
