#!/bin/bash
#
# package-and-notarize.sh
#
# Builds a universal Release of Shed, signs it (and its bundled helper
# binaries), and packages a .dmg. If a Developer ID and notary profile are
# provided it also notarizes and staples; otherwise it produces a deep
# ad-hoc-signed build for the interim "download + allow in System Settings"
# beta flow.
#
# Usage:
#   ./Scripts/package-and-notarize.sh [version]
#
# Environment:
#   DEVELOPER_ID    e.g. "Developer ID Application: Jane Doe (TEAMID)"
#   NOTARY_PROFILE  keychain profile from `xcrun notarytool store-credentials`
#
# Set up the notary profile once:
#   xcrun notarytool store-credentials "Shed-Notary" \
#     --apple-id you@example.com --team-id TEAMID --password <app-specific-pw>
#
# Then a full release is:
#   DEVELOPER_ID="Developer ID Application: Jane Doe (TEAMID)" \
#   NOTARY_PROFILE="Shed-Notary" ./Scripts/package-and-notarize.sh 1.0.0-beta.1

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-beta}"
PROJECT="Shed.xcodeproj"
SCHEME="Shed"
APP_NAME="Shed.app"
BUILD_DIR="build"
DIST_DIR="dist"
DMG="$DIST_DIR/Shed-$VERSION.dmg"

if [ ! -x "Vendor/bin/yt-dlp" ] || [ ! -x "Vendor/bin/ffmpeg" ]; then
  echo "error: Vendor/bin binaries missing — run ./Scripts/fetch-vendor-binaries.sh first" >&2
  exit 1
fi

echo "→ Building universal Release…"
rm -rf "$BUILD_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" build >/dev/null

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME"
[ -d "$APP" ] || { echo "error: build did not produce $APP" >&2; exit 1; }

echo "→ Architectures: $(lipo -archs "$APP/Contents/MacOS/Shed")"

# Build the codesign argument list for either Developer ID or ad-hoc.
SIGN=(codesign --force)
if [ -n "${DEVELOPER_ID:-}" ]; then
  SIGN+=(--options runtime --timestamp --sign "$DEVELOPER_ID")
  echo "→ Signing with Developer ID: $DEVELOPER_ID"
else
  SIGN+=(--sign -)   # ad-hoc
  echo "→ No DEVELOPER_ID set — using ad-hoc signing (interim beta)."
fi

# Sign inner binaries first, then the app bundle (inside-out).
"${SIGN[@]}" "$APP/Contents/Resources/bin/ffmpeg"
"${SIGN[@]}" "$APP/Contents/Resources/bin/yt-dlp"
"${SIGN[@]}" "$APP"
codesign --verify --deep --strict "$APP" && echo "→ Signature verified."

echo "→ Building $DMG…"
mkdir -p "$DIST_DIR"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Shed" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

if [ -n "${DEVELOPER_ID:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "→ Notarizing (this can take a minute)…"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  echo "✓ Notarized and stapled: $DMG"
else
  cat <<EOF

✓ Built (ad-hoc, NOT notarized): $DMG

Beta testers: after copying Shed to Applications and double-clicking once,
open System Settings ▸ Privacy & Security ▸ "Open Anyway". If audio import
fails afterward (Gatekeeper blocking the bundled tools), run once:
  xattr -dr com.apple.quarantine /Applications/Shed.app

For a friction-free install, set DEVELOPER_ID and NOTARY_PROFILE and re-run.
EOF
fi
