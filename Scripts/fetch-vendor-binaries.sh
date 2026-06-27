#!/bin/bash
#
# fetch-vendor-binaries.sh
#
# Downloads self-contained, universal (arm64 + x86_64) copies of yt-dlp and
# ffmpeg into Vendor/bin/. These get copied into Shed.app/Contents/Resources/bin
# at build time, so beta testers don't need Homebrew or any setup.
#
# Run once from the project root (the folder containing Shed.xcodeproj):
#   ./Scripts/fetch-vendor-binaries.sh
#
# The binaries are large and intentionally git-ignored; re-run this on a fresh
# clone or to update to the latest versions.

set -euo pipefail

cd "$(dirname "$0")/.."
DEST="Vendor/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST"

echo "→ Downloading yt-dlp (universal)…"
curl -fSL --retry 3 -o "$DEST/yt-dlp" \
  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"

echo "→ Downloading ffmpeg (x86_64)…"
curl -fSL --retry 3 -o "$TMP/ff-intel.zip" "https://evermeet.cx/ffmpeg/getrelease/zip"
unzip -oq "$TMP/ff-intel.zip" -d "$TMP/intel"

echo "→ Downloading ffmpeg (arm64)…"
curl -fSL --retry 3 -o "$TMP/ff-arm.zip" "https://www.osxexperts.net/ffmpeg81arm.zip"
unzip -oq "$TMP/ff-arm.zip" -d "$TMP/arm"

echo "→ Combining into a universal ffmpeg…"
lipo -create "$TMP/intel/ffmpeg" "$TMP/arm/ffmpeg" -output "$DEST/ffmpeg"

chmod +x "$DEST/yt-dlp" "$DEST/ffmpeg"

echo
echo "Done. Vendored binaries:"
for b in yt-dlp ffmpeg; do
  printf '  %-8s %s  [%s]\n' "$b" \
    "$(du -h "$DEST/$b" | cut -f1)" "$(lipo -archs "$DEST/$b" | tr '\n' ' ')"
done
echo
echo "Now build Shed in Xcode — the binaries will be embedded in the app."
