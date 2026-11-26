#!/bin/bash
# Records one tour of the app on demo data, posts the video as a comment on the pull request and prints the video's link.
# The app records itself, so no Screen Recording permission is needed. Nothing is added to the repo:
# the files stay in artifacts/tmp/ (ignored) and GitHub hosts the video.
#
# Usage: scripts/pr-video.sh <tour> [<pr number>] [--skip-build] [--no-post]
#   <tour>        a tour name from `Horion --walkthrough <tour>` (e2e, tab, all-day-drag, v4-d-3, ...)
#   <pr number>   default: the pull request of the current branch
#   --skip-build  use the app that is already in build/
#   --no-post     make the video, do not post it
# Output: artifacts/tmp/<tour>.mp4 (1080p, 30 fps, with the tour's captions, under 10 MB so GitHub accepts it).
set -euo pipefail
cd "$(dirname "$0")/.."

TOUR=""; PR=""; BUILD=1; POST=1
for arg in "$@"; do
  case "$arg" in
    --skip-build) BUILD=0 ;;
    --no-post) POST=0 ;;
    -*) echo "unknown flag $arg"; exit 2 ;;
    *) if [ -z "$TOUR" ]; then TOUR="$arg"; else PR="$arg"; fi ;;
  esac
done
[ -n "$TOUR" ] || { sed -n '2,11p' "$0"; exit 2; }
command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)"; exit 1; }

BIN=build/Horion.app/Contents/MacOS/Horion
[ $BUILD -eq 0 ] || scripts/build-app.sh 2>&1 | tail -2
[ -x "$BIN" ] || { echo "$BIN not found: run without --skip-build"; exit 1; }

mkdir -p artifacts/tmp
MOV="artifacts/tmp/$TOUR.mov"; RAW="artifacts/tmp/$TOUR.raw.mp4"; OUT="artifacts/tmp/$TOUR.mp4"
rm -f "$MOV" "$MOV".*.json "$RAW" "$OUT"

# The tour checks the app while it records. A failed check stops here: a video of a broken tour is not evidence.
"$BIN" --walkthrough "$TOUR" --record "$MOV" | tail -4
rm -f "$MOV".sb-*

LIMIT=$((10 * 1024 * 1024))   # GitHub's size limit for a video on the free plan
for HEIGHT in 1080 720; do
  ffmpeg -v error -y -i "$MOV" -vf "scale=-2:$HEIGHT" -r 30 -c:v libx264 -crf 26 -preset medium \
    -pix_fmt yuv420p -movflags +faststart -an "$RAW"
  [ "$(stat -f %z "$RAW")" -le $LIMIT ] && break
done
[ "$(stat -f %z "$RAW")" -le $LIMIT ] || { echo "the video is over 10 MB even at 720p: record a shorter tour"; exit 1; }

# Captions say what each step does. They need Pillow; without it the video is posted without captions.
if [ -s "$MOV.captions.json" ] && python3 -c "import PIL" 2>/dev/null; then
  python3 scripts/caption-video.py "$RAW" "$MOV.captions.json" "$OUT" >/dev/null
  [ "$(stat -f %z "$OUT")" -le $LIMIT ] || cp "$RAW" "$OUT"
else
  cp "$RAW" "$OUT"
fi
ls -lh "$OUT" | awk '{print $NF ": " $5}'

[ $POST -eq 1 ] || exit 0
[ -n "$PR" ] || PR="$(gh pr view --json number --jq .number)"
gh pr comment "$PR" --body "Video of the \`$TOUR\` tour, recorded by the app on demo data." --attach "$OUT" >/dev/null
# GitHub plays this link as a video when it stands on a line of its own. Put it into the PR text: Luis reads only that.
gh pr view "$PR" --json comments --jq '.comments[].body' | grep -o 'https://github.com/user-attachments/assets/[A-Za-z0-9-]*' | tail -1 || true
