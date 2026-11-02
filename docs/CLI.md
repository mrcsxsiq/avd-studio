# Command line

`avdstudio` is the same core as the app, for terminals and scripts. It ships inside the app; the
[Homebrew cask](INSTALL.md#homebrew) links it into your `PATH`. Back to the [README](../README.md).

## Commands

```text
avdstudio list [--json]                      List the virtual devices
avdstudio start <name> [--cold-boot] [--wipe-data] [--print-command]
avdstudio create -n <name> -i <image> -d <device> [--ram MB] [--storage 16G] [--sdcard 512M] [--display-name TEXT]
avdstudio delete <name> [--yes]              Delete a device and its data (asks unless --yes)
avdstudio images [--json]                    System images installed in the SDK (what --image accepts)
avdstudio images --available [--all-abis]    Images Google offers for download (needs Java and the network)
avdstudio images install <package>… [--accept-licenses]
                                             Download images (you accept Google's license first)
avdstudio images remove <package> [--yes] [--force]
                                             Remove an installed image (--force when devices use it)
avdstudio devices [--type phone|tv|…] [--json]   Hardware definitions (what --device accepts)
avdstudio doctor [--json]                    Check the SDK, Java and devices; prints numbered next steps
avdstudio setup [--dry-run] [--script] [--accept-licenses]
                                             Install what is missing (Homebrew + sdkmanager)
avdstudio sdk-path                           Print the SDK folder in use
```

`avdstudio <command> --help` describes every option.

## Create and start a device

Pick a hardware definition (the `ID` column) and an installed system image (the `PACKAGE` column), then create and
start the device. Quote the package: it contains `;`.

```bash
avdstudio devices --type phone
avdstudio images
avdstudio create -n my-phone -i "system-images;android-36;google_apis_playstore;arm64-v8a" -d medium_phone
avdstudio start my-phone
```

Need another Android version first? `avdstudio images --available` lists what Google offers, and
`avdstudio images install <package> --accept-licenses` downloads it. You are accepting
[Google's licence](https://developer.android.com/studio/terms) by passing that flag; AVD Studio never does it for you.

## Options common to every command

- `--sdk-path` and `--avd-home` (or the environment variables `AVDSTUDIO_SDK_PATH` / `AVDSTUDIO_AVD_HOME`)
  override auto-detection.
- Colours are only used on a terminal.
- `--json` output is stable, so scripts can rely on it.
- Exit status is 0 on success and 1 when something is wrong (`doctor` treats a missing `adb` as a warning, not a
  failure).

## `doctor`

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

The app shows the same checks in Settings > Android > Diagnostics.
