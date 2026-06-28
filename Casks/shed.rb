cask "shed" do
  version "1.0.0-beta.5"
  # shasum -a 256 Shed-1.0.0-beta.5.dmg
  sha256 "c2902a4514e777cc8f2d41b72b5fdca154a01b5b6531f86b453333a25ef87c4c"

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
