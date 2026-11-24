#!/bin/bash
# Builds build/Horion.app. Set SIGNING_IDENTITY for Developer ID signing (hardened runtime, secure timestamp).
# Version: VERSION (repo root) is CFBundleShortVersionString; CFBundleVersion is HORION_BUILD, else the number of commits
# (it grows with every commit on main, which is what Sparkle compares). HORION_FEED_URL overrides SUFeedURL (tests).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION="$(tr -d ' \t\r\n' < VERSION)"
BUILD="${HORION_BUILD:-$(git rev-list --count HEAD)}"
FEED_URL="${HORION_FEED_URL:-https://github.com/luisKisters/horion/releases/latest/download/appcast.xml}"
# Sparkle's EdDSA public key. The private key stays in the login keychain of the Mac that publishes releases (README, "Updates").
ED_PUBLIC_KEY="veseyIKBVOUnFRtqA/BDwk82kRVUD33ODSzBA1eKB8U="

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Horion"

APP=build/Horion.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/Horion"
scripts/make-icon.sh   # no-op when design/icon/AppIcon.icns is newer than the SVGs
cp design/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Geist (variable, SIL OFL 1.1) and its licence; Typeface.swift looks in Contents/Resources/Fonts first
mkdir -p "$APP/Contents/Resources/Fonts"
cp "Sources/Horion/Resources/Fonts/Geist[wght].ttf" Sources/Horion/Resources/Fonts/Geist-OFL.txt "$APP/Contents/Resources/Fonts/"

# Sparkle 2 (the update framework, a binary package from SwiftPM) goes into Contents/Frameworks. ditto keeps its symlinks.
SPARKLE_SRC="$(find .build/artifacts -type d -name Sparkle.framework -path '*macos*' | sed -n '1p')"
[ -n "$SPARKLE_SRC" ] || { echo "Sparkle.framework not found under .build/artifacts (run: swift package resolve)"; exit 1; }
ditto "$SPARKLE_SRC" "$APP/Contents/Frameworks/Sparkle.framework"
# The binary loads Sparkle through @rpath; this adds the bundle's Frameworks folder once.
if ! otool -l "$APP/Contents/MacOS/Horion" | grep "path @executable_path/../Frameworks" >/dev/null; then
  install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Horion"
fi

# Google Calendar API (v4 Phase 8b): only when HORION_GOOGLE_CLIENT_ID is set (an iOS-type OAuth client ID, never committed).
# It goes into Info.plist with its reversed-client-ID URL scheme, which ASWebAuthenticationSession receives the sign-in redirect on.
GOOGLE_PLIST=""
if [ -n "${HORION_GOOGLE_CLIENT_ID:-}" ]; then
  case "$HORION_GOOGLE_CLIENT_ID" in *.apps.googleusercontent.com) ;; *) echo "HORION_GOOGLE_CLIENT_ID must end in .apps.googleusercontent.com"; exit 1 ;; esac
  GOOGLE_SCHEME="com.googleusercontent.apps.${HORION_GOOGLE_CLIENT_ID%.apps.googleusercontent.com}"
  GOOGLE_PLIST="<key>HorionGoogleClientID</key><string>$HORION_GOOGLE_CLIENT_ID</string>
  <key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>Google sign-in</string><key>CFBundleURLSchemes</key><array><string>$GOOGLE_SCHEME</string></array></dict></array>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Horion</string>
  <key>CFBundleDisplayName</key><string>Horion</string>
  <key>CFBundleIdentifier</key><string>com.luiskisters.horion</string>
  <key>CFBundleExecutable</key><string>Horion</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Horion shows and edits the events in your Google, iCloud and local calendars.</string>
  <key>NSCalendarsUsageDescription</key><string>Horion shows and edits the events in your Google, iCloud and local calendars.</string>
  $GOOGLE_PLIST
  <key>NSContactsUsageDescription</key><string>Horion shows the names of guests that events list only by their email address, and suggests people when you add participants.</string>
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>$ED_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUAutomaticallyUpdate</key><true/>
  <key>SUScheduledCheckInterval</key><integer>3600</integer>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Sign inside-out in the order of Sparkle's manual-signing guide: XPC services, Autoupdate, Updater.app, the framework, then the app.
# No --deep (Sparkle's guide: it would not re-sign the helpers correctly). Without SIGNING_IDENTITY everything is ad-hoc signed.
sign() {
  if [ -n "${SIGNING_IDENTITY:-}" ]; then
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$@"
  else
    codesign --force --sign - "$@"
  fi
}
SPK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for xpc in "$SPK"/XPCServices/*.xpc; do
  [ -e "$xpc" ] || continue
  sign --preserve-metadata=entitlements "$xpc"
done
sign "$SPK/Autoupdate"
sign "$SPK/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"

if [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp --entitlements scripts/Horion.entitlements "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built $APP (version $VERSION, build $BUILD)"
