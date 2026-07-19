cask "shed" do
  version "1.0.0-beta.7"
  # shasum -a 256 Shed-1.0.0-beta.7.dmg
  sha256 "1ce32b6276e170e77e36dc687ff21b1eaa933318963bf971643fb758761523d6"

  url "https://github.com/willdickerson/shed/releases/download/v#{version}/Shed-#{version}.dmg"
  name "Shed"
  desc "Local-only transcription tool for musicians"
  homepage "https://github.com/willdickerson/shed"

  # Match (or lower) the project's MACOSX_DEPLOYMENT_TARGET.
  depends_on macos: :sonoma

  app "Shed.app"

  # yt-dlp, ffmpeg, and deno are bundled inside the app, so no dependencies are needed.

  zap trash: [
    "~/Library/Application Support/Shed",
    "~/Library/Preferences/net.willdickerson.Shed.plist",
  ]
end
