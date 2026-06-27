cask "shed" do
  version "1.0.0-beta.1"
  # shasum -a 256 Shed-1.0.0-beta.1.dmg
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/OWNER/REPO/releases/download/v#{version}/Shed-#{version}.dmg"
  name "Shed"
  desc "Local-only transcription tool for musicians"
  homepage "https://github.com/OWNER/REPO"

  # Match (or lower) the project's MACOSX_DEPLOYMENT_TARGET.
  depends_on macos: ">= :sonoma"

  app "Shed.app"

  # yt-dlp and ffmpeg are bundled inside the app, so no dependencies are needed.

  zap trash: [
    "~/Library/Application Support/Shed",
    "~/Library/Preferences/net.willdickerson.Shed.plist",
  ]
end
