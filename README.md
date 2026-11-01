<p align="center">
  <img src="macos/App/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="AVD Studio icon">
</p>

<h1 align="center">AVD Studio</h1>

<p align="center">
  A native macOS app and command-line tool for Android Virtual Devices.<br>
  Browse your emulators as a colourful grid, start them from the menu bar, keep using your own Android SDK.
</p>

<p align="center">
  <a href="https://github.com/mrcsxsiq/avd-studio/actions/workflows/ci.yml"><img src="https://github.com/mrcsxsiq/avd-studio/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B%20(Apple%20Silicon)-lightgrey" alt="macOS 14+, Apple Silicon">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/app-dark.png">
    <img src="docs/images/app-light.png" width="800" alt="The AVD Studio window: a sidebar grouping devices by type and a grid of gradient cards, one per emulator">
  </picture>
</p>

> **Status:** early software. [0.1.0 is out](https://github.com/mrcsxsiq/avd-studio/releases/latest): a DMG, the `avdstudio` CLI and a Homebrew tap.
> The first builds are not notarized yet, so macOS may ask you to right-click the app and choose **Open** once.
> Website: https://mrcsxsiq.github.io/avd-studio/ (and https://avdstudio.dev once the domain is connected).

## What it does

- **See every emulator at a glance.** Each virtual device is a card with its own gradient, grouped in the sidebar by type: phone, foldable, tablet, Wear OS, TV, automotive, desktop and XR. Search by name, Android version or device profile.
- **Create and delete devices.** The New Device sheet (⌘N) takes a type, a hardware definition, one of your installed Android versions, a name, RAM, storage and an SD card, and turns on Google Play, the GPU and the device frame like Android Studio does. Delete asks first.
- **Start and stop with one click or a double-click.** Per-device actions: start, stop, cold boot, wipe data and start (with confirmation), show in Finder, copy name. Emulators started from Android Studio or a terminal show up as running too.
- **Menu bar.** Every device is listed with a play button (stopped) or a stop button (running), plus New Device…, so you can start, test and stop emulators without opening the window. Pick the icon from ten options (a phone, a tablet, a watch, a little droid…); a dot shows when something is running.
- **Set up Android in one click.** No SDK? AVD Studio installs Google's command-line tools, a Java runtime, the emulator and the system images your devices need (through Homebrew and `sdkmanager`). Without Homebrew it gives you a script for Terminal. Already have an SDK? Point to it.
- **Your folders, your rules.** Choose the SDK folder and the virtual-device folder (for example on an external SSD). Nothing is moved and Android Studio's settings are untouched.
- **Light, dark or system theme.**
- **Updates built in.** Shows the installed version next to the new one with release notes, downloads the DMG and verifies its SHA-256, and notifies you when a version is released. Automatic checks can be turned off.
- **A real CLI.** `avdstudio list`, `start`, `create`, `delete`, `images`, `devices`, `doctor`, `setup` and `sdk-path`, with `--json` for scripts.
- **No analytics, no accounts.** The only network traffic is the optional update check against the GitHub Releases API.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/menu-bar-dark.png">
    <img src="docs/images/menu-bar-light.png" width="340" alt="The menu bar popover listing running emulators and the rest grouped by type">
  </picture>
  &nbsp;&nbsp;
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/update-dark.png">
    <img src="docs/images/update-light.png" width="420" alt="The Software Update window showing the installed version, the new version and release notes">
  </picture>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/create-dark.png">
    <img src="docs/images/create-light.png" width="380" alt="The New Virtual Device sheet: type, hardware, Android version, name, RAM, storage and SD card">
  </picture>
  &nbsp;&nbsp;
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/setup-dark.png">
    <img src="docs/images/setup-light.png" width="380" alt="The Set up Android sheet listing the commands it will run and asking you to accept the Android SDK License Agreement">
  </picture>
</p>

## Requirements

- An Apple Silicon Mac running macOS 14 (Sonoma) or newer.
- The Android command-line tools, emulator and `adb` (AVD Studio can install them for you; see [First run](#first-run)).
- A Java runtime for `sdkmanager`/`avdmanager` (also installed for you if missing).

AVD Studio never bundles the Android SDK. It runs the tools that are on your Mac, under Google's own licence.

## Install

| Way | How |
| --- | --- |
| DMG | Download `AVD-Studio-<version>.dmg` from [Releases](https://github.com/mrcsxsiq/avd-studio/releases), open it and drag the app to Applications. |
| Homebrew | See below. |

**Homebrew.** This repository is its own tap, so it is added with its URL. Since Homebrew 6.0, casks and
formulae from third-party taps only load once you trust them; installing by the **full name** trusts just that
one item:

```bash
brew tap mrcsxsiq/avd-studio https://github.com/mrcsxsiq/avd-studio
brew install --cask mrcsxsiq/avd-studio/avd-studio   # the app and the avdstudio command
```

The command-line tool ships inside the app, so this one cask gives you both: Homebrew links `avdstudio` into your
`PATH`. (Versions before 0.2.0 had a separate `avdstudio` formula; it is gone.) Releases are not notarized yet, so
the cask also clears the download quarantine flag from the app; without that macOS would block the app and kill the
command on its first run. The DMG route does not do this: the first time, right-click the app and choose Open.

To use the short name (`brew install --cask avd-studio`) trust the cask first:

```bash
brew trust --cask mrcsxsiq/avd-studio/avd-studio
# or, to trust everything this tap will ever publish: brew trust --tap mrcsxsiq/avd-studio
```

Update later with `brew upgrade --cask avd-studio` (the app can also tell you when a new version is out).
`brew untrust` takes trust back.

Prefer to build it yourself? See [Build from source](#build-from-source).

## First run

AVD Studio looks for an SDK in `ANDROID_SDK_ROOT`, `ANDROID_HOME`, Android Studio's default folder
(`~/Library/Android/sdk`) and Homebrew's `android-commandlinetools`, in that order. Virtual devices are read from
`~/.android/avd` (or `ANDROID_AVD_HOME`).

If nothing usable is found you get a setup screen with two routes:

- **Install Automatically…** lists exactly what will run (`brew install --cask android-commandlinetools`,
  `brew install openjdk@17`, `sdkmanager …`), asks you to accept the Android SDK License Agreement, then does it
  all and switches to the new SDK. Without Homebrew the same steps become a script you can open in Terminal.
- **I Already Have an SDK…** lets you choose the folder.

Settings → Diagnostics shows the same checks later, with a **Fix Automatically…** button when something is missing.

## Command line

```text
avdstudio list [--json]                      List the virtual devices
avdstudio start <name> [--cold-boot] [--wipe-data] [--print-command]
avdstudio create -n <name> -i <image> -d <device> [--ram MB] [--storage 16G] [--sdcard 512M] [--display-name TEXT]
avdstudio delete <name> [--yes]              Delete a device and its data (asks unless --yes)
avdstudio images [--json]                    System images installed in the SDK (what --image accepts)
avdstudio devices [--type phone|tv|…] [--json]   Hardware definitions (what --device accepts)
avdstudio doctor [--json]                    Check the SDK, Java and devices; prints numbered next steps
avdstudio setup [--dry-run] [--script] [--accept-licenses]
                                             Install what is missing (Homebrew + sdkmanager)
avdstudio sdk-path                           Print the SDK folder in use
```

`--sdk-path` and `--avd-home` (or `AVDSTUDIO_SDK_PATH` / `AVDSTUDIO_AVD_HOME`) override auto-detection on every
command. Colours are only used on a terminal; `--json` output is stable for scripting. Exit status is 0 on success,
1 when something is wrong (`doctor` treats a missing `adb` as a warning, not a failure).

```console
$ avdstudio doctor
✓ Android SDK  /Users/you/Library/Android/sdk (Android Studio default)
✓ sdkmanager  /Users/you/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager
✓ avdmanager  /Users/you/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager
✗ emulator  Not found (expected at /Users/you/Library/Android/sdk/emulator/emulator).
✓ adb  /Users/you/Library/Android/sdk/platform-tools/adb
✓ Java runtime  /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
✓ Virtual device folder  /Users/you/.android/avd — 3 device(s)

Next steps
  1. Install the missing SDK packages with `sdkmanager --sdk_root=/Users/you/Library/Android/sdk "emulator"`.

Then run `avdstudio doctor` again to check.
```

## Settings

| Tab | What you can change |
| --- | --- |
| General | Theme (System, Light or Dark); where AVD Studio appears: the Dock, the menu bar or both (never neither, so you can always get back in), and one of ten menu bar icons; automatic update checks and Check for Updates… |
| Android | The SDK folder (leave empty for auto-detection); the folder that holds the `.avd` files; Diagnostics (the same checks as `avdstudio doctor`) with Fix Automatically… |
| About | The version, a **Star on GitHub** button and links to the website, changelog and license. Also reachable from the menu bar popover (the ⓘ icon) and the app menu. |

## How it works

```text
core/    Kotlin Multiplatform (Kotlin/Native, macosArm64)   SDK/Java detection, AVD reader, emulator control,
                                                            doctor, setup planner. No UI, no Java at runtime.
cli/     Kotlin/Native executable (Clikt)                    `avdstudio`, built on core.
macos/   Swift package + XcodeGen project                    AVDStudioUI (SwiftUI, no Kotlin), AVDStudioKit (the
                                                            only module that imports the Kotlin framework), App/.
website/ Static landing page                                 Deployed to GitHub Pages.
```

The core is compiled to an XCFramework and consumed by the app as a static framework. Everything the UI needs goes
through one Swift protocol (`DeviceService`), so views and view models are tested with fakes and the Kotlin bridge is
tested against the real core in a temporary home folder. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Virtual devices are read straight from the `.ini`/`config.ini` files, not through `avdmanager`: it is instant, needs
no Java, and also shows devices whose system image is missing (with a way to fix it).

## Build from source

You need Xcode 16 or newer (Swift 6), a JDK 17 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
`make bootstrap` installs the last two with Homebrew.

```bash
git clone https://github.com/mrcsxsiq/avd-studio.git
cd avd-studio
make bootstrap      # xcodegen + openjdk@17 (Brewfile)
make core           # Kotlin core -> macos/Frameworks/AVDStudioCore.xcframework
make app            # Release build of the app (build/xcode/Build/Products/Release/AVD Studio.app)
make install        # …and copy it to /Applications
make cli            # cli/build/bin/macosArm64/releaseExecutable/avdstudio.kexe
make test           # Kotlin + Swift tests, including screenshot tests
```

`make help` lists every target. Open `macos/AVDStudio.xcodeproj` (generated by `make generate`) to work in Xcode.

## Contributing

Bug reports, ideas and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the setup, the
test rules and the review checklist, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for how we treat each other.
Working with an AI agent? [AGENTS.md](AGENTS.md) has the instructions it needs.

Releases follow [Semantic Versioning](https://semver.org); every user-visible change is listed in
[CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) © Marcos Paulo Farias. Third-party components are listed in [LICENSES.md](LICENSES.md).

Android is a trademark of Google LLC. Apple, macOS, Swift and SwiftUI are trademarks of Apple Inc. AVD Studio is an
independent project, not affiliated with or endorsed by Google or Apple.
