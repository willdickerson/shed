cask "shed" do
  version "1.0.0-beta.2"
  # shasum -a 256 Shed-1.0.0-beta.2.dmg
  sha256 "5b2f5898602b3a88c1310ddbcc1674442bb109b20250fe8d6851ec8b32ede092"

  url "https://github.com/willdickerson/shed/releases/download/v#{version}/Shed-#{version}.dmg"
  name "Shed"
  desc "Local-only transcription tool for musicians"
  homepage "https://github.com/willdickerson/shed"

  # Match (or lower) the project's MACOSX_DEPLOYMENT_TARGET.
  depends_on macos: :sonoma

  app "Shed.app"

  # yt-dlp and ffmpeg are bundled inside the app, so no dependencies are needed.

  zap trash: [
    "~/Library/Application Support/Shed",
    "~/Library/Preferences/net.willdickerson.Shed.plist",
  ]
end
