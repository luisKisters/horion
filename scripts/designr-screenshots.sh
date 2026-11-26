#!/bin/bash
# Design screenshots for the designr skill: renders every state in design/states.json offscreen into
# artifacts/screenshots/<name>.png, so a design round can look at the real app next to its mockup.
#
# This is NOT a test and verifies nothing. Do not run it to check a change: use scripts/verify.sh.
# It launches the app once per state (52 states, several minutes, heavy on the CPU), so it asks for
# --designr to make sure it only runs on purpose.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != "--designr" ]; then
  echo "designr-screenshots.sh renders design screenshots for the designr skill. It is not a test." >&2
  echo "To verify a change, run scripts/verify.sh --fast. To render the screenshots anyway: $0 --designr" >&2
  exit 2
fi
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG" >/dev/null
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Horion"
OUT=artifacts/screenshots
mkdir -p "$OUT"
fail=0
while IFS=$'\t' read -r name state size; do
  if ! "$BIN" --snapshot "$state" --out "$OUT/$name.png" --size "$size" >/dev/null; then echo "FAILED: $name"; fail=1; fi
done < <(python3 - <<'PY'
import json
d = json.load(open("design/states.json"))
for name, s in d["states"].items():
    print(f"{name}\t{s.get('state', name)}\t{s.get('size', d['size'])}")
PY
)
[ $fail -eq 0 ] && echo "rendered $(ls "$OUT"/*.png | wc -l | tr -d ' ') screenshots into $OUT"
exit $fail
