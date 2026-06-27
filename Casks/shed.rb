cask "shed" do
  version "1.0.0-beta.1"
  # shasum -a 256 Shed-1.0.0-beta.1.dmg
  sha256 "837678522efdf3cae7e11d73695748e8fc2063e663ab333ddc731f07e89ab315"

  url "https://github.com/willdickerson/shed/releases/download/v#{version}/Shed-#{version}.dmg"
  name "Shed"
  desc "Local-only transcription tool for musicians"
  homepage "https://github.com/willdickerson/shed"

  # Match (or lower) the project's MACOSX_DEPLOYMENT_TARGET.
  depends_on macos: :sequoia

  app "Shed.app"

  # yt-dlp and ffmpeg are bundled inside the app, so no dependencies are needed.

  zap trash: [
    "~/Library/Application Support/Shed",
    "~/Library/Preferences/net.willdickerson.Shed.plist",
  ]
end
