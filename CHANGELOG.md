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
- Setup screen when no Android SDK is found, with a folder picker and the Homebrew install command.
- Settings to choose the SDK folder and the virtual-device folder (for example on an external drive),
  show or hide the menu bar item, and run diagnostics.
- `avdstudio` command-line tool with `list`, `start`, `doctor` and `sdk-path`; `list` and `doctor`
  support `--json`, and `--sdk-path` / `--avd-home` (or `AVDSTUDIO_SDK_PATH` / `AVDSTUDIO_AVD_HOME`)
  override auto-detection.

[Unreleased]: https://github.com/mrcsxsiq/avd-studio/commits/main
