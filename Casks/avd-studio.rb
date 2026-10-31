cask "avd-studio" do
  version "0.1.0"
  sha256 "ed8014e0bf02a52537af77ae5278817da7bb9141a518c22df1f5b1c761a788c0"

  url "https://github.com/mrcsxsiq/avd-studio/releases/download/v#{version}/AVD-Studio-#{version}.dmg"
  name "AVD Studio"
  desc "Native manager for Android Virtual Devices"
  homepage "https://github.com/mrcsxsiq/avd-studio"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "AVD Studio.app"

  zap trash: [
    "~/Library/Application Support/dev.marcos.avdstudio",
    "~/Library/Caches/dev.marcos.avdstudio",
    "~/Library/HTTPStorages/dev.marcos.avdstudio",
    "~/Library/Preferences/dev.marcos.avdstudio.plist",
    "~/Library/Saved Application State/dev.marcos.avdstudio.savedState",
  ]

  caveats <<~EOS
    AVD Studio manages the Android SDK tools that are already on your Mac; it does not install them.
    If you have none yet, run:  avdstudio doctor
    (the command-line tool: brew install mrcsxsiq/avd-studio/avdstudio)

    Until releases are notarized, macOS may refuse to open the app the first time.
    Right-click the app and choose Open, or run:
      xattr -dr com.apple.quarantine "#{appdir}/AVD Studio.app"
  EOS
end
