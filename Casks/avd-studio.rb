cask "avd-studio" do
  version "0.4.0"
  sha256 "c9b3bf8f0d2d0c6707b79705fb84efaafb320893bc9da03f02766a620125e046"

  url "https://github.com/mrcsxsiq/avd-studio/releases/download/v#{version}/AVD-Studio-#{version}.dmg"
  name "AVD Studio"
  desc "Native manager for Android Virtual Devices"
  homepage "https://github.com/mrcsxsiq/avd-studio"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "AVD Studio.app"
  # The command-line tool ships inside the app; Homebrew links it into the PATH, so one install gives both.
  binary "#{appdir}/AVD Studio.app/Contents/Helpers/avdstudio"

  # Releases are not notarized yet. With the download's quarantine flag still on, Gatekeeper kills the bundled
  # `avdstudio` the first time it runs and blocks the app. Clear the flag on the app this project built.
  # Remove this block when the releases are notarized (see docs/RELEASING.md).
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/AVD Studio.app"]
  end

  zap trash: [
    "~/Library/Application Support/dev.marcos.avdstudio",
    "~/Library/Caches/dev.marcos.avdstudio",
    "~/Library/HTTPStorages/dev.marcos.avdstudio",
    "~/Library/Preferences/dev.marcos.avdstudio.plist",
    "~/Library/Saved Application State/dev.marcos.avdstudio.savedState",
  ]

  caveats <<~EOS
    This installed the app and the `avdstudio` command (it lives inside the app and was linked into your PATH).

    AVD Studio manages the Android SDK tools that are already on your Mac. If you have none yet, open the app:
    it can install them for you. From a terminal, `avdstudio doctor` says what is missing.

    Releases are not notarized yet, so this cask removes the download quarantine flag from the app. Without that,
    macOS would block the app and kill the `avdstudio` command the first time it runs.
  EOS
end
