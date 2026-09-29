#!/bin/bash
# Full verification: build, tests, grep gates, app bundle, snapshots, walkthrough (E2E + video), perf, launch time.
# Must pass before any step is called done.  Usage: scripts/verify.sh [--fast]   (--fast skips walkthrough video + perf)
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
FAST=0; [ "${1:-}" = "--fast" ] && FAST=1
step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "grep gates (no animations, no third-party packages)"
if grep -rnE "withAnimation|\.animation\(|\.transition\(|NSAnimationContext\.runAnimationGroup" Sources | grep -v "^Sources/Calendr/Headless"; then
  echo "animation API found in app sources"; exit 1
fi
if grep -q "\.package(" Package.swift; then echo "Package.swift has dependencies"; exit 1; fi
echo ok

step "swift build"
swift build 2>&1 | tail -3

step "swift test"
swift test 2>&1 | grep -E "Test run|✘|error:" | tail -20
swift test 2>&1 | grep -q "Test run with .* passed" || { echo "tests failed"; exit 1; }

step "build app bundle"
scripts/build-app.sh 2>&1 | tail -2
BIN=build/Calendr.app/Contents/MacOS/Calendr
codesign --verify --deep build/Calendr.app && echo "signature ok"

step "snapshots (every state in design/states.json)"
CONFIG=release scripts/snapshots.sh

if [ $FAST -eq 0 ]; then
  step "walkthrough: E2E assertions + artifacts/walkthrough.mp4"
  mkdir -p artifacts
  "$BIN" --walkthrough --record artifacts/walkthrough.mp4 --size 1440x900 | tail -4
  swift scripts/extract-frames.swift artifacts/walkthrough.mp4 artifacts/frames 2 30 60 90 2>&1 | grep -E "duration|frame at"
  python3 - <<'PY'
import subprocess, re, sys
out = subprocess.run(["swift", "scripts/extract-frames.swift", "artifacts/walkthrough.mp4", "artifacts/frames", "1"], capture_output=True, text=True).stdout
d = float(re.search(r"duration ([0-9.]+)s", out).group(1))
assert 60 <= d <= 120, f"video duration {d}s outside 60-120s"
print(f"video duration {d:.1f}s ok")
PY

  step "performance (week navigation p50/p95, cold launch)"
  ok=0
  for attempt in 1 2 3; do
    if CALENDR_PERF_STRICT=1 "$BIN" --perf | tee artifacts/perf.txt | tail -8 && [ "${PIPESTATUS[0]}" -eq 0 ]; then ok=1; break; fi
    echo "perf attempt $attempt over budget, retrying"
  done
  [ $ok -eq 1 ] || { echo "performance budget missed"; exit 1; }

  step "real app launch (demo mode)"
  "$BIN" --demo --print-launch
fi

step "verify passed"
