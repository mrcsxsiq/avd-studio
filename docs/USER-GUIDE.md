# User guide

What AVD Studio does and how to set it up. Back to the [README](../README.md); to install it, see
[Installing and updating](INSTALL.md).

- [First run](#first-run)
- [Devices](#devices)
- [Menu bar](#menu-bar)
- [System images](#system-images)
- [Your folders and theme](#your-folders-and-theme)
- [Updates](#updates)
- [Privacy](#privacy)
- [Settings](#settings)

## First run

AVD Studio looks for an SDK in `ANDROID_SDK_ROOT`, `ANDROID_HOME`, Android Studio's default folder
(`~/Library/Android/sdk`) and Homebrew's `android-commandlinetools`, in that order. Virtual devices are read from
`~/.android/avd` (or `ANDROID_AVD_HOME`).

If nothing usable is found you get a setup screen with two routes:

- **Install Automatically…** lists exactly what will run (`brew install --cask android-commandlinetools`,
  `brew install openjdk@17`, `sdkmanager …`), asks you to accept the Android SDK License Agreement, then does it
  all and switches to the new SDK. Without Homebrew the same steps become a script you can open in Terminal.
- **I Already Have an SDK…** lets you choose the folder.

AVD Studio never accepts Google's licence for you: you tick the box first. Settings > Android > Diagnostics shows
the same checks later, with a **Fix Automatically…** button when something is missing.

## Devices

- **See every emulator at a glance.** Each virtual device is a card with its own gradient, grouped in the sidebar
  by type: phone, foldable, tablet, Wear OS, TV, automotive, desktop and XR. Search by name, Android version or
  device profile.
- **Create devices.** The New Device sheet (⌘N) takes a type, a hardware definition, one of your installed Android
  versions, a name, RAM, storage and an SD card, and turns on Google Play, the GPU and the device frame like
  Android Studio does. If the Android version you want is not installed, the sheet links straight to
  [Settings > System Images](#system-images).
- **Delete devices.** Delete asks first.
- **Start and stop with one click or a double-click.** Per-device actions: start, stop, cold boot, wipe data and
  start (with confirmation), show in Finder, copy name. Emulators started from Android Studio or a terminal show up
  as running too.

## Menu bar

Every device is listed with a play button (stopped) or a stop button (running), plus New Device…, so you can start,
test and stop emulators without opening the window. Pick the icon from ten options (a phone, a tablet, a watch, a
little droid…); a dot shows when something is running.

You can show AVD Studio in the Dock, the menu bar or both (never neither, so you can always get back in).

## System images

Settings > System Images lists what is installed, with the room each image takes and which devices use it.

- **Download more Android versions** with **Download More Images…**. The dialog asks Google for what can be
  downloaded (phones, tablets, TV, Wear OS, Automotive, Desktop, XR; Apple Silicon images only) and lets you filter
  by device type; previews and test images are hidden until you ask. Tick the images, accept Google's licence and
  press Download. A progress bar shows which image and how many GB have arrived, and the download goes on in the
  background if you close the dialog.
- **Remove** the ones you no longer need with the trash button. Devices that use an image are listed first, and a
  running emulator blocks removal.

## Your folders and theme

Choose the SDK folder and the virtual-device folder (for example on an external SSD). Nothing is moved and Android
Studio's settings are untouched. The theme is light, dark or the system's.

## Updates

Check for updates and press **Install** to apply a new version; AVD Studio handles Homebrew-managed and
DMG-installed copies differently, and explains what went wrong if it cannot finish. See
[Updating](INSTALL.md#updating) for the details. Automatic checks can be turned off.

## Privacy

No analytics, no accounts. The only network traffic of AVD Studio itself is the optional update check against the
GitHub Releases API. Android packages (setup, system images) are downloaded by Google's own `sdkmanager`, and only
when you ask for them.

## Settings

| Tab | What you can change |
| --- | --- |
| General | Theme (System, Light or Dark); where AVD Studio appears: the Dock, the menu bar or both (never neither, so you can always get back in), and one of ten menu bar icons |
| Android | The SDK folder (leave empty for auto-detection); the folder that holds the `.avd` files; Diagnostics (the same checks as `avdstudio doctor`) with Fix Automatically… |
| System Images | The installed images with their size and the devices that use them; **Download More Images…** and the trash button. See [System images](#system-images). |
| Updates | The installed and latest versions, what's new in the release (Markdown rendered), **Install** (Homebrew upgrade or download from GitHub, then the app reopens), Check for Updates and the switch for automatic checks. |
| About | The version, a **Star on GitHub** button and links to the website, changelog and license. Also reachable from the menu bar popover (the ⓘ icon) and the app menu. |
