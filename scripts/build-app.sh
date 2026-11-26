#!/bin/bash
# Builds build/Horion.app. Set SIGNING_IDENTITY for Developer ID signing.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Google Calendar API (v4 Phase 8b): needs an iOS-type OAuth client ID, which is never committed. Looked up in this order:
#   1. HORION_GOOGLE_CLIENT_ID in the environment (CI sets it from the repository variable of the same name)
#   2. HORION_GOOGLE_CLIENT_ID=... in ~/.config/horion/build.env (one file per machine, see README "Build configuration")
#   3. the HorionGoogleClientID of the installed /Applications/Horion.app
# HORION_REQUIRE_GOOGLE=1 (and any SIGNING_IDENTITY release build) fails instead of building without Google sign-in.
# The ID goes into Info.plist with its reversed-client-ID URL scheme, which ASWebAuthenticationSession receives the sign-in redirect on.
BUILD_ENV="${HORION_BUILD_ENV:-$HOME/.config/horion/build.env}"
if [ -z "${HORION_GOOGLE_CLIENT_ID:-}" ] && [ -f "$BUILD_ENV" ]; then
  HORION_GOOGLE_CLIENT_ID="$(grep -E '^[[:space:]]*(export[[:space:]]+)?HORION_GOOGLE_CLIENT_ID=' "$BUILD_ENV" | tail -1 | sed -E 's/^[^=]*=//; s/[[:space:]]+#.*$//; s/["'"'"'[:space:]]//g' || true)"
fi
if [ -z "${HORION_GOOGLE_CLIENT_ID:-}" ] && [ -f /Applications/Horion.app/Contents/Info.plist ]; then
  HORION_GOOGLE_CLIENT_ID="$(/usr/libexec/PlistBuddy -c 'Print :HorionGoogleClientID' /Applications/Horion.app/Contents/Info.plist 2>/dev/null || true)"
fi
if [ -z "${HORION_GOOGLE_CLIENT_ID:-}" ]; then
  if [ "${HORION_REQUIRE_GOOGLE:-0}" = 1 ] || [ -n "${SIGNING_IDENTITY:-}" ]; then
    echo "FAIL: no HORION_GOOGLE_CLIENT_ID (environment, $BUILD_ENV or the installed app), and this build requires Google sign-in" >&2; exit 1
  fi
  echo "note: no HORION_GOOGLE_CLIENT_ID (environment, $BUILD_ENV or the installed app), this build has no Google sign-in" >&2
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Horion"

APP=build/Horion.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Horion"
scripts/make-icon.sh   # no-op when design/icon/AppIcon.icns is newer than the SVGs
cp design/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Geist (variable, SIL OFL 1.1) and its licence; Typeface.swift looks in Contents/Resources/Fonts first
mkdir -p "$APP/Contents/Resources/Fonts"
cp "Sources/Horion/Resources/Fonts/Geist[wght].ttf" Sources/Horion/Resources/Fonts/Geist-OFL.txt "$APP/Contents/Resources/Fonts/"

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
  <key>CFBundleShortVersionString</key><string>1.1.1</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Horion shows and edits the events in your Google, iCloud and local calendars.</string>
  <key>NSCalendarsUsageDescription</key><string>Horion shows and edits the events in your Google, iCloud and local calendars.</string>
  $GOOGLE_PLIST
  <key>NSContactsUsageDescription</key><string>Horion shows the names of guests that events list only by their email address, and suggests people when you add participants.</string>
</dict>
</plist>
PLIST

if [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp --entitlements scripts/Horion.entitlements "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built $APP"
