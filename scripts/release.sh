#!/bin/bash
# Publishes a Horion release: builds dist/Horion.dmg, signs it with Sparkle's EdDSA key (login keychain), writes
# dist/appcast.xml with one item, and creates the GitHub release build-<build> with both files. Installed copies check
# https://github.com/luisKisters/horion/releases/latest/download/appcast.xml and install the newest build by themselves.
#   scripts/release.sh --dry-run   does everything except creating the release, and prints what it would upload
#   scripts/release.sh             publishes (needs gh logged in with push access to the repo)
# Env: SIGNING_IDENTITY and NOTARY_PROFILE (Developer ID + notarization, passed to make-dmg.sh; a real release needs both),
#      HORION_BUILD (build number, default: the commit count), HORION_REPO (default luisKisters/horion).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DRY_RUN=0
case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=1 ;;
  *) echo "usage: scripts/release.sh [--dry-run]"; exit 2 ;;
esac
REPO="${HORION_REPO:-luisKisters/horion}"
SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27   # the GitHub release asset's digest
die() { echo "release: $*" >&2; exit 1; }
step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "checkout is a clean copy of origin/main"
git fetch --quiet origin main
[ -z "$(git status --porcelain)" ] || die "the working tree has changes or untracked files; commit or remove them first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "HEAD is not origin/main; merge the branch and run from main"
SHA="$(git rev-parse HEAD)"
VERSION="$(tr -d ' \t\r\n' < VERSION)"
BUILD="${HORION_BUILD:-$(git rev-list --count HEAD)}"
TAG="build-$BUILD"
TITLE="Horion $VERSION ($BUILD)"
DMG_URL="https://github.com/$REPO/releases/download/$TAG/Horion.dmg"
echo "$TITLE from $(git rev-parse --short HEAD)"
EXISTING_TAG="$(git ls-remote --tags origin "refs/tags/$TAG")" || die "cannot reach origin"
[ -z "$EXISTING_TAG" ] || die "tag $TAG already exists on origin"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then die "release $TAG already exists on $REPO"; fi

step "Sparkle tools $SPARKLE_VERSION (the version the app is built against, checked against the release asset's SHA-256)"
PINNED="$(python3 -I -c 'import json; d = json.load(open("Package.resolved")); print(next(p["state"]["version"] for p in d["pins"] if p["identity"] == "sparkle"))')"
[ "$PINNED" = "$SPARKLE_VERSION" ] || die "Package.resolved pins Sparkle $PINNED, release.sh expects $SPARKLE_VERSION"
TOOLS="build/tools/Sparkle-$SPARKLE_VERSION"
if [ ! -x "$TOOLS/bin/sign_update" ]; then
  mkdir -p build/tools
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "build/tools/Sparkle-$SPARKLE_VERSION.tar.xz"
  echo "$SPARKLE_SHA256  build/tools/Sparkle-$SPARKLE_VERSION.tar.xz" | shasum -a 256 -c - >/dev/null || die "the Sparkle tools tarball does not match its SHA-256"
  mkdir -p "$TOOLS"
  tar -xJf "build/tools/Sparkle-$SPARKLE_VERSION.tar.xz" -C "$TOOLS"
fi

if [ -n "${SIGNING_IDENTITY:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "Developer ID signing and notarization: on"
elif [ "$DRY_RUN" = 1 ]; then
  echo "note: no SIGNING_IDENTITY/NOTARY_PROFILE, so this dry run builds an ad-hoc signed DMG (a real release needs both)"
else
  die "a real release needs SIGNING_IDENTITY (Developer ID) and NOTARY_PROFILE (notarytool keychain profile); use --dry-run to test without them"
fi

step "build dist/Horion.dmg (scripts/make-dmg.sh: build, sign, notarize when set, verify the mounted DMG)"
scripts/make-dmg.sh

step "check the app and the signature"
APP_PLIST=build/Horion.app/Contents/Info.plist
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST")" = "$BUILD" ] || die "the app's CFBundleVersion is not $BUILD"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PLIST")" = "$VERSION" ] || die "the app's version is not $VERSION"
KEY_IN_APP="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PLIST")"
KEY_IN_KEYCHAIN="$("$TOOLS/bin/generate_keys" -p)" || die "no Sparkle signing key in this Mac's login keychain (see README, Updates)"
[ "$KEY_IN_APP" = "$KEY_IN_KEYCHAIN" ] || die "the app's SUPublicEDKey does not match the signing key in this Mac's keychain"
SIG="$("$TOOLS/bin/sign_update" -p dist/Horion.dmg)"
LEN="$(stat -f %z dist/Horion.dmg)"
"$TOOLS/bin/sign_update" --verify dist/Horion.dmg "$SIG" >/dev/null || die "the EdDSA signature of dist/Horion.dmg does not verify"
echo "EdDSA signature ok, $LEN bytes"

step "write dist/appcast.xml (one item)"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_PLIST")"
case "$MIN_OS" in *.*.*) ;; *.*) MIN_OS="$MIN_OS.0" ;; *) MIN_OS="$MIN_OS.0.0" ;; esac
PUBDATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Horion</title>
    <item>
      <title>$TITLE</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <enclosure url="$DMG_URL" sparkle:edSignature="$SIG" length="$LEN" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
xmllint --noout dist/appcast.xml
[ "$(xmllint --xpath 'count(//item)' dist/appcast.xml)" = 1 ] || die "the appcast must have exactly one item"
echo "appcast.xml ok: one item, enclosure $DMG_URL"

if [ "$DRY_RUN" = 1 ]; then
  step "dry run: nothing was published"
  echo "would create the GitHub release \"$TITLE\" on $REPO with tag $TAG at $SHA, marked latest"
  echo "would upload: dist/Horion.dmg ($LEN bytes) and dist/appcast.xml"
  echo "installed copies would download: $DMG_URL"
  exit 0
fi

step "publish GitHub release $TAG"
gh release create "$TAG" dist/Horion.dmg dist/appcast.xml --repo "$REPO" --target "$SHA" --title "$TITLE" \
  --notes "Horion $VERSION (build $BUILD), built from $(git rev-parse --short "$SHA")." --latest
echo "published: https://github.com/$REPO/releases/tag/$TAG"
