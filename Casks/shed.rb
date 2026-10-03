cask "shed" do
  version "1.0.0-beta.9"
  # shasum -a 256 Shed-1.0.0-beta.9.dmg
  sha256 "6c942cf89232172b1d5c8da0846e283626e2f15d754e5aea95adde7582601da2"

  url "https://github.com/willdickerson/shed/releases/download/v#{version}/Shed-#{version}.dmg"
  name "Shed"
  desc "Local-only transcription tool for musicians"
  homepage "https://github.com/willdickerson/shed"

  # Match (or lower) the project's MACOSX_DEPLOYMENT_TARGET.
  depends_on macos: :ventura

  app "Shed.app"

  # yt-dlp, ffmpeg, and deno are bundled inside the app, so no dependencies are needed.

  zap trash: [
    "~/Library/Application Support/Shed",
    "~/Library/Preferences/net.willdickerson.Shed.plist",
  ]
end
