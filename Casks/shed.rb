cask "shed" do
  version "1.0.0-beta.4"
  # shasum -a 256 Shed-1.0.0-beta.4.dmg
  sha256 "80d0c2fa00c612cee171659d953310b4b534c47fce07e347abe4bad38f8bc7b6"

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
