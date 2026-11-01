# Changelog

All notable changes to AVD Studio are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**How we maintain this file:** every pull request that changes behaviour a user can see (app, CLI,
install, requirements) adds a line under `## [Unreleased]` in the matching group. When a version is
released, `scripts/release.sh` renames `Unreleased` to the version and date and opens a fresh
`Unreleased` section. The release workflow publishes that section as the GitHub release notes.

Groups, in this order: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

## [Unreleased]

### Added

- **Install from GitHub** in the update window and Settings > Updates, offered when Homebrew could not finish the
  upgrade (its tap is updated a little after a release, or `brew` failed). It downloads and verifies the DMG, replaces
  the app and reopens it, without asking Homebrew again.

### Fixed

- **Delete** (and **Wipe Data and Start**) did nothing when confirmed. Closing the confirmation dialog cleared the
  device before the button's action ran, so the action found nothing to delete and returned without a word. The
  device now travels with the button.
- **Delete…** from the menu bar popover showed no confirmation when the main window was closed (always the case with
  the Dock icon hidden). It now brings up the window with the question.
- Deleting a device no longer needs Java or the command-line tools: when `avdmanager` cannot run, its files are
  removed directly, which is all it does. This also covers devices whose system image is missing.
- A device whose `.ini` pointed at a folder that is not an `.avd` folder could make `avdmanager delete avd` remove
  that folder (checked against the real tool). AVD Studio now refuses before running anything, and names that
  would leave the AVD folder (`../x`) are refused too.
- Installing an update no longer fails when macOS answers "Resource temporarily unavailable" while mounting the
  DMG (the disk image service is busy): it tries again a couple of times. A file that is not a disk image still
  fails at once.

## [0.4.0] - 2026-11-01

### Added

- **Download More Images…** in Settings > System Images opens a dialog (the list Google offers, the license box and
  Download) and the download runs in the background with a progress bar: which image, how many of them, and how many
  gigabytes have arrived. Close the dialog and it keeps going, and the progress shows at the top of the tab.
  `sdkmanager` reports no percentage and never the size of a package, so the bar moves but does not fill.
- **Install** in the update window: with Homebrew it runs `brew upgrade --cask` for you; otherwise it downloads the
  DMG from GitHub, checks its SHA-256 and the app's signature, replaces the app and reopens it. When it cannot (no
  permission to write to Applications, Homebrew's tap not yet updated, no published checksum) it says why and leaves
  the installer for you.
- **Updates** tab in Settings: installed and latest version, what's new, Install, Check for Updates and the automatic
  check switch (they used to live in General).
- A **Settings** button (gear) next to "Android SDK ready" in the sidebar. It opens on the Android tab when the SDK
  needs setup.

### Changed

- System images are downloaded one at a time, so the progress can say which one. If a later image fails, the ones that
  already arrived stay installed and only the failed one stays selected.
- "What's new" in the update window draws the release notes' Markdown (headings, lists, bold, code, links) instead of
  showing it as plain text, and the Homebrew command it offers is fully qualified
  (`brew upgrade --cask mrcsxsiq/avd-studio/avd-studio`).

## [0.3.0] - 2026-11-01

### Added

- **System Images** tab in Settings. It lists the installed images with the space each takes and the devices that use
  it, downloads more Android versions (Google Play, Google APIs, default, TV, Wear OS, Automotive, Desktop, XR; only
  Apple Silicon images are offered) after you accept the Android SDK License Agreement, and removes images you no
  longer need, naming the devices that would stop working. The list of what Google offers is only fetched when you
  press Show Available Images. The New Device sheet links to this tab (Download Images… when a type has none, Get More
  Android Versions… otherwise) and picks up an image the moment it is installed.
- Command line: `avdstudio images --available [--all-abis]`, `avdstudio images install <package>… --accept-licenses`
  and `avdstudio images remove <package> [--yes] [--force]`; `avdstudio images --json` now includes each image's size.

### Changed

- Installed system images are named like the ones you can download (Google TV, Google Play (16 KB pages)…) instead of
  the text Google writes inside each image, and `avdstudio images` has a SIZE column.

### Fixed

- Google XR system images (`google-xr`, `ai-glasses`) were classed as phone images, so they were offered when
  creating a phone and missing when creating an XR device.

## [0.2.0] - 2026-11-01

### Added

- An About page with the version, a **Star on GitHub** button that opens the repository (the app has no GitHub
  account, so one click on Star there does it) and links to the website, changelog and license. Open it from the
  app menu (About AVD Studio), from the menu bar popover (the ⓘ icon) or from the new About tab in
  Settings.
- The `avdstudio` command-line tool now ships inside the app (`AVD Studio.app/Contents/Helpers/avdstudio`), so
  one install gives you both.
- A **Check for Updates** icon in the menu bar popover. The icons there now run Settings, Check for Updates,
  About and Quit, after Refresh.
- **Show AVD Studio in the Dock** (Settings > General). Switch it off to keep the app only in the menu bar: it
  then starts quietly, without opening its window (macOS 15 and later), and opens windows from the popover. Together with the existing
  menu bar switch you can keep either one or both, but never neither: the last place that is on cannot be switched
  off, and a stored "both off" is repaired to Dock-on when the app starts.

### Changed

- Settings are split into three tabs: General (appearance, menu bar, updates), Android (SDK and virtual device
  folders, diagnostics, which now start with the Run Diagnostics and Fix buttons) and About.
- Homebrew: the cask now installs the app and the `avdstudio` command together (it links the copy that ships inside
  the app into your PATH), and its `depends_on macos:` no longer triggers a deprecation warning. Until the releases
  are notarized the cask also clears the download quarantine flag from the app: with it, macOS killed the bundled
  `avdstudio` on its first run and blocked the app.

### Removed

- The separate `avdstudio` Homebrew formula and the `avdstudio-<version>-macos-arm64.tar.gz` release asset. If you
  installed the formula, run `brew uninstall avdstudio` and `brew install --cask mrcsxsiq/avd-studio/avd-studio`.

### Fixed

- The menu bar popover showed only its header and footer and no devices. The list had no height of its own and
  the menu bar window is sized from the content's minimum size, so it collapsed. It now has an explicit height
  (with scrolling past about 420 pt) and a regression test that measures the popover the way the menu bar does.

## [0.1.0] - 2026-10-31

### Added

- Kotlin Multiplatform core shared by the macOS app and the command-line tool.
- Android SDK detection: explicit path, `ANDROID_SDK_ROOT`, `ANDROID_HOME`, Android Studio's default
  folder and Homebrew's `android-commandlinetools`, including versioned `cmdline-tools/<n>` folders.
- Java detection (`JAVA_HOME`, SDKMAN, Homebrew, system JVMs, Android Studio's bundled JDK) and an
  explicit environment for `sdkmanager`/`avdmanager`, so apps launched from Finder do not depend on the shell.
- Reading of virtual devices straight from `~/.android/avd` (or `ANDROID_AVD_HOME`, or a folder you pick),
  including devices whose `.ini` name differs from the folder name and devices with a missing system image.
- Device type detection: phone, foldable, tablet, Wear OS, TV, automotive, desktop and XR.
- Detection of running emulators and the ability to stop them.
- Native macOS app (SwiftUI): a colourful grid of virtual devices with a gradient card per device, grouped
  in the sidebar by type (phone, foldable, tablet, Wear OS, TV, automotive, desktop, XR), search, and
  double-click to start. Per-device actions: start, stop, cold boot, wipe data and start (with
  confirmation), show in Finder.
- Menu bar item to start, test and stop emulators without opening the window; it shows how many are running.
- One-click setup when no Android SDK is found: the app lists what it will run (`brew install --cask
  android-commandlinetools`, `brew install openjdk@17`, `sdkmanager` for the emulator, platform tools and the
  system images your devices need), asks you to accept the Android SDK License Agreement, runs the steps with
  their output visible, and switches to the new SDK. Without Homebrew it hands you the same steps as a script to
  open in Terminal. Settings → Diagnostics has the same "Fix Automatically…" button. Already have an SDK? Pick the folder.
- `avdstudio setup` does the same from the terminal (`--dry-run`, `--script`, `--accept-licenses`).
- Settings to choose the SDK folder and the virtual-device folder (for example on an external drive),
  show or hide the menu bar item, and run diagnostics.
- Create and delete virtual devices. The New Device sheet (⌘N, toolbar, menu bar, empty state) takes a type, a
  hardware definition, one of the installed system images, a name, RAM, storage and an SD card, and enables
  Google Play, the GPU and the device frame like Android Studio does. Delete (context menu) asks first and
  refuses while the device is running. CLI: `avdstudio create`, `delete`, `images` and `devices`.
- The menu bar list shows every device with a play button (stopped) or a stop button (running) and a
  New Device… entry; clicking a row starts it right away.
- Software update: Settings and the app menu ("Check for Updates…") show the installed version next to the
  new one with its release notes, then download the DMG with SHA-256 verification. A native notification
  announces a new release (once per version), and you can turn automatic checks off in Settings. Copies
  installed with Homebrew are pointed to `brew upgrade --cask avd-studio` instead.
- Theme setting: follow the system, or force light or dark.
- Choose the menu bar icon from 10 options (phone, phone & tablet, tablet, watch, TV, car, play, terminal,
  bolt and a little droid); a dot on the icon shows that an emulator is running.
- New app icon.
- `avdstudio` command-line tool with `list`, `start`, `doctor` and `sdk-path`; `doctor` ends with numbered
  next steps and copy-pasteable commands (including the exact `sdkmanager "system-images;…"` package for each
  device whose image is missing) and `--help` explains what it checks, its exit codes and examples; `list` and
  `doctor` support `--json`, and `--sdk-path` / `--avd-home` (or `AVDSTUDIO_SDK_PATH` / `AVDSTUDIO_AVD_HOME`)
  override auto-detection.

[Unreleased]: https://github.com/mrcsxsiq/avd-studio/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.4.0
[0.3.0]: https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.3.0
[0.2.0]: https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.2.0
[0.1.0]: https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.1.0
