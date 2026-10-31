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

[Unreleased]: https://github.com/mrcsxsiq/avd-studio/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mrcsxsiq/avd-studio/releases/tag/v0.1.0
