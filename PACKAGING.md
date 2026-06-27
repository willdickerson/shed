# Packaging Shed for beta testers

Shed bundles **yt-dlp** and **ffmpeg** inside the app, so testers need no
Homebrew and no setup. This guide covers building, distributing, and the
optional Homebrew install path.

## 1. Fetch the bundled binaries (once)

```sh
./Scripts/fetch-vendor-binaries.sh
```

This downloads universal (arm64 + x86_64) copies of yt-dlp and ffmpeg into
`Vendor/bin/`. They're git-ignored (large), so re-run on a fresh clone or to
update versions. The Xcode build copies them into
`Shed.app/Contents/Resources/bin/` and marks them executable.

At runtime `BinaryLocator` searches in order:
**bundled → `/opt/homebrew/bin` → `/usr/local/bin` → `PATH`**, and only errors
if nothing usable is found.

## 2. Build a universal release (arm64 + Intel)

Use **Product ▸ Archive** in Xcode, or a **generic** destination — both produce
a universal app (`x86_64 + arm64`) that runs on Intel and Apple Silicon:

```sh
xcodebuild -project Shed.xcodeproj -scheme Shed -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build build
# app: build/Build/Products/Release/Shed.app
```

> Don't build with a concrete `-destination 'platform=macOS'` (or a Debug
> build) for distribution — those compile only the current Mac's architecture.
> Verify with: `lipo -archs Shed.app/Contents/MacOS/Shed` → should list both.
> The bundled helpers are already universal. Intel testers need macOS 15+
> (Sequoia still supports 2018–2020 Intel Macs).

> The bundled ffmpeg is large (~125 MB universal), so the app is ~170 MB. To
> slim it, ship an arm64-only ffmpeg (edit `fetch-vendor-binaries.sh` to skip the
> lipo step) — but that drops Intel support.

## 3. Sign & notarize (required for non-technical testers)

The app is **not** sandboxed (it launches yt-dlp/ffmpeg), so TestFlight/App
Store is out — distribute a signed, notarized `.dmg` directly. Without this,
Gatekeeper blocks the download on every tester's Mac.

```sh
# Sign the app and its nested helper binaries with a Developer ID + hardened runtime
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  Shed.app/Contents/Resources/bin/yt-dlp \
  Shed.app/Contents/Resources/bin/ffmpeg
codesign --force --options runtime --timestamp --deep \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" Shed.app

# Package and notarize
hdiutil create -volname Shed -srcfolder Shed.app -ov -format UDZO Shed-1.0.0-beta.1.dmg
xcrun notarytool submit Shed-1.0.0-beta.1.dmg --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple Shed-1.0.0-beta.1.dmg
```

Without a Developer ID, testers can still run it via right-click ▸ Open (or
`xattr -dr com.apple.quarantine Shed.app`) — fine for a tiny private beta, not
for a wider one.

## 4. Optional: install via Homebrew

`Casks/shed.rb` is a ready cask. To let testers `brew install` it:

1. Create a tap repo named `homebrew-tap` under your GitHub account.
2. Put `Casks/shed.rb` in it, filling in `OWNER/REPO`, `version`, and the dmg
   `sha256` (`shasum -a 256 Shed-*.dmg`).
3. Upload the notarized dmg to that release tag.

Testers then run:

```sh
brew install --cask OWNER/tap/shed
```

The cask declares no dependencies because the binaries are bundled.
