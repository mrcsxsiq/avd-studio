# Installing and updating

How to get AVD Studio onto your Mac, keep it up to date and remove it. Back to the [README](../README.md).

## Requirements

- An Apple Silicon Mac running macOS 14 (Sonoma) or newer.
- The Android command-line tools, emulator and `adb`. AVD Studio can install them for you; see
  [First run](USER-GUIDE.md#first-run).
- A Java runtime for `sdkmanager`/`avdmanager` (also installed for you if missing).

AVD Studio never bundles the Android SDK. It runs the tools that are on your Mac, under Google's own licence.

## Install

| Way | How |
| --- | --- |
| DMG | Download `AVD-Studio-<version>.dmg` from [Releases](https://github.com/mrcsxsiq/avd-studio/releases), open it and drag the app to Applications. |
| Homebrew | See below. |

### Homebrew

This repository is its own tap, so it is added with its URL. Since Homebrew 6.0, casks and formulae from
third-party taps only load once you trust them; installing by the **full name** trusts just that one item:

```bash
brew tap mrcsxsiq/avd-studio https://github.com/mrcsxsiq/avd-studio
brew install --cask mrcsxsiq/avd-studio/avd-studio   # the app and the avdstudio command
```

The command-line tool ships inside the app, so this one cask gives you both: Homebrew links `avdstudio` into your
`PATH`. (Versions before 0.2.0 had a separate `avdstudio` formula; it is gone.)

To use the short name (`brew install --cask avd-studio`) trust the cask first:

```bash
brew trust --cask mrcsxsiq/avd-studio/avd-studio
# or, to trust everything this tap will ever publish: brew trust --tap mrcsxsiq/avd-studio
```

`brew untrust` takes trust back.

### Gatekeeper and notarization

Releases are **not notarized yet**. What that means depends on how you installed:

- **Homebrew:** the cask clears the download quarantine flag from the app. Without that, macOS would block the app
  and kill the `avdstudio` command on its first run.
- **DMG:** the first time, right-click the app and choose **Open**.

## Updating

Press **Install** in the update window or in Settings > Updates, or run:

```bash
brew upgrade --cask mrcsxsiq/avd-studio/avd-studio
```

What **Install** does depends on how the app got there:

- **Managed by Homebrew:** AVD Studio runs that cask upgrade in the background.
- **Installed from the DMG:** it downloads the DMG from GitHub, verifies its SHA-256 and the app's signature,
  replaces the app and reopens it. No Terminal command needs to be copied.

If something goes wrong the app explains why:

- When Homebrew cannot finish (its tap is updated a little after a release), it offers **Install from GitHub**.
- When replacing the app fails (for example no permission to write to Applications), the downloaded DMG stays in
  Downloads for you to open yourself.

Release notes are shown in the app with their Markdown drawn. The app can also notify you when a version is
released; automatic checks can be turned off in Settings > Updates.

## Uninstalling

- **Homebrew:** `brew uninstall --cask mrcsxsiq/avd-studio/avd-studio` removes the app and the `avdstudio` link.
  Add `--zap` to also delete its preferences, caches and saved state.
- **DMG:** drag **AVD Studio** from Applications to the Trash.

Your virtual devices and your Android SDK live in their own folders and are never touched.

## Build it yourself

See [Build from source](../README.md#build-from-source) and [CONTRIBUTING.md](../CONTRIBUTING.md#setup).
