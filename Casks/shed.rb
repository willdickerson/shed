cask "shed" do
  version "1.0.0-beta.3"
  # shasum -a 256 Shed-1.0.0-beta.3.dmg
  sha256 "c09d0adde8160eee54ca98b212856023212cc0655f23e3e3c225eedc61438d52"

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
