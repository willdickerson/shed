cask "shed" do
  version "1.0.0-beta.8"
  # shasum -a 256 Shed-1.0.0-beta.8.dmg
  sha256 "164564393477d90c1c0a070e87ea2446d798a0657cb5b9ef00390e3e4824339c"

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
