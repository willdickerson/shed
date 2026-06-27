# Shed — Beta

A local-only transcription tool for musicians: open an audio file or a YouTube
link, slow it down without changing pitch, shift pitch, and loop short phrases
while you transcribe.

## Install

1. Download **Shed-1.0.0-beta.1.dmg** (link below).
2. Open the dmg and drag **Shed** into **Applications**.
3. Double-click Shed. macOS will block it the first time ("Apple could not
   verify…") because this beta isn't notarized yet — this is expected.
4. Open **System Settings ▸ Privacy & Security**, scroll to the bottom, and
   click **Open Anyway** next to the Shed message. Confirm.

### If audio import fails after opening

Shed bundles its helper tools, but macOS may still quarantine them. If opening a
file or YouTube link doesn't work, run this once in **Terminal**:

```sh
xattr -dr com.apple.quarantine /Applications/Shed.app
```

Then reopen Shed.

### Already use Homebrew?

You can skip all of the above:

```sh
brew install --cask --no-quarantine willdickerson/tap/shed
```

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel — the app and its tools are universal
- No setup needed: yt-dlp and ffmpeg are bundled

## What to try

1. Import audio (Open Audio File… or Import from YouTube…).
2. Drag across the waveform to select a phrase, press **Space** to loop it.
3. Drop the **Speed** and nudge **Pitch** as needed.
4. Try **Detect Tuning Offset** in the Pitch panel.

Shortcuts: Space play/pause · ←/→ skip 5s · L loop · Esc clear loop ·
[ / ] set loop start/end · − / = slower/faster.

## Reporting issues

Please note your macOS version, whether you're on Apple Silicon or Intel, the
file/URL you used, and what you expected vs. what happened.
