#!/bin/bash
# Builds Horion and installs it to /Applications, replacing and restarting the running instance.
#   scripts/install.sh        the current checkout (including uncommitted changes)
#   scripts/install.sh main   the latest origin/main, built in a temporary worktree
# The Google client ID comes from wherever build-app.sh finds it (environment, ~/.config/horion/build.env, the installed app).
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
APP=/Applications/Horion.app

case "${1:-}" in
  "") SRC="$REPO"; echo "Building the current checkout ($(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD))" ;;
  main)
    git fetch -q origin main
    SRC="$(mktemp -d)/horion-main"
    git worktree add -q --detach "$SRC" origin/main
    trap 'git -C "$REPO" worktree remove --force "$SRC"' EXIT
    echo "Building origin/main @ $(git rev-parse --short origin/main)" ;;
  *) echo "usage: scripts/install.sh [main]"; exit 1 ;;
esac

# build before quitting, so a failed build leaves the running app alone
"$SRC/scripts/build-app.sh"

# quit Horion (and any old Calendr build), politely first
osascript -e 'tell application id "com.luiskisters.horion" to quit' >/dev/null 2>&1 || true
for _ in $(seq 20); do pgrep -f 'Horion.app/Contents/MacOS/Horion|Calendr.app/Contents/MacOS/Calendr' >/dev/null || break; sleep 0.25; done
pkill -f 'Horion.app/Contents/MacOS/Horion|Calendr.app/Contents/MacOS/Calendr' 2>/dev/null || true

if [ -d "$APP" ]; then trash "$APP"; fi
cp -R "$SRC/build/Horion.app" "$APP"
open "$APP"
echo "Installed and started $APP"
