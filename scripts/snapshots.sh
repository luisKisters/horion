#!/bin/bash
# Renders every state in design/states.json into artifacts/snapshots/<state>.png (offscreen, no screen access needed).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG" >/dev/null
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Calendr"
OUT=artifacts/snapshots
mkdir -p "$OUT"
SIZE=$(python3 -c "import json;print(json.load(open('design/states.json'))['size'])")
fail=0
for state in $(python3 -c "import json;print(' '.join(json.load(open('design/states.json'))['states']))"); do
  if ! "$BIN" --snapshot "$state" --out "$OUT/$state.png" --size "$SIZE" >/dev/null; then echo "FAILED: $state"; fail=1; fi
done
[ $fail -eq 0 ] && echo "rendered $(ls "$OUT"/*.png | wc -l | tr -d ' ') snapshots into $OUT"
exit $fail
