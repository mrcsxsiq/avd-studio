# Third-party licenses

AVD Studio itself is released under the [MIT License](LICENSE).

It is built on the open-source components below. Each keeps its own license; the versions listed are
the ones pinned in [`gradle/libs.versions.toml`](gradle/libs.versions.toml) and
[`macos/Package.resolved`](macos/Package.resolved) at the time of writing. Dependabot bumps them, so
when a dependency is added or replaced, update this file in the same pull request.

## Shipped with the app and the CLI

These are compiled into the released binaries.

| Component | Version | License | Used by |
| --- | --- | --- | --- |
| [Kotlin standard library](https://github.com/JetBrains/kotlin) | 2.4.21 | Apache-2.0 | core, CLI |
| [Okio](https://github.com/square/okio) | 3.18.2 | Apache-2.0 | core, CLI |
| [kotlinx.serialization](https://github.com/Kotlin/kotlinx.serialization) | 1.12.0 | Apache-2.0 | CLI |
| [Clikt](https://github.com/ajalt/clikt) | 5.1.0 | Apache-2.0 | CLI |
| [Mordant](https://github.com/ajalt/mordant) (through Clikt) | 3.0.2 | Apache-2.0 | CLI |
| [colormath](https://github.com/ajalt/colormath) (through Mordant) | 3.6.0 | MIT | CLI |

## Development and testing only

These are used to build, lint and test the project. They are not part of the released binaries.

| Component | Version | License | Purpose |
| --- | --- | --- | --- |
| [ktlint](https://github.com/pinterest/ktlint) | 1.8.0 | MIT | Kotlin linting |
| [ktlint-gradle](https://github.com/JLLeitschuh/ktlint-gradle) | 14.2.0 | MIT | Gradle integration for ktlint |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | 1.19+ | MIT | Screenshot tests |

`swift-snapshot-testing` pulls in further Swift packages (for example `swift-custom-dump` and
`xctest-dynamic-overlay`, both MIT, and `swift-syntax`, Apache-2.0 with the Runtime Library
Exception). `macos/Package.resolved` lists the exact set.

## Android tools are not bundled

AVD Studio does not include or redistribute any part of the Android SDK. It runs the `sdkmanager`,
`avdmanager`, `emulator` and `adb` that are already installed on your Mac (or that you choose to
install). Those tools and the system images they download are provided by Google under the
[Android Software Development Kit License Agreement](https://developer.android.com/studio/terms),
which you accept when you use them.

## Trademarks

Android and the Android robot are trademarks of Google LLC. Apple, macOS, Swift and SwiftUI are
trademarks of Apple Inc. AVD Studio is an independent project and is not affiliated with, endorsed
by, or sponsored by Google or Apple.

## License texts

- MIT: <https://opensource.org/license/mit>
- Apache License 2.0: <https://www.apache.org/licenses/LICENSE-2.0>
