# AGENTS.md

Instructions for AI coding agents (and a fast orientation for humans) working in this repository.
Read this whole file before changing anything.

## What this project is

AVD Studio is a native macOS app plus a CLI to manage Android Virtual Devices. Three parts, one repository:

| Path | Tech | Role |
| --- | --- | --- |
| `core/` | Kotlin Multiplatform, Kotlin/Native `macosArm64` only | All logic: SDK/Java detection, reading AVDs, running emulators, doctor, setup planner. Public API is `AvdStudioCore` (`core/src/commonMain/kotlin/dev/marcos/avdstudio/core/AvdStudioCore.kt`). |
| `cli/` | Kotlin/Native + Clikt | `avdstudio` binary. Thin: parsing, output formatting, exit codes. |
| `macos/` | Swift 6, SwiftUI, SwiftPM + XcodeGen | `Sources/AVDStudioUI` (views, `@Observable` models, **no Kotlin imports**), `Sources/AVDStudioKit` (the only module that imports `AVDStudioCore`; maps Kotlin types to Swift types), `App/` (composition root: window, `MenuBarExtra`, Settings, update window). |
| `website/` | Static HTML/CSS/JS | Landing page, deployed by `.github/workflows/pages.yml`. |
| `Casks/` | Ruby | This repo is also the Homebrew tap: one cask installs the app and links the CLI that ships inside it. Updated by the release workflow, never by hand. |

Package/bundle identifier: `dev.marcos.avdstudio`. Version: the `VERSION` file is the single source of truth
(Gradle, the Xcode project, `avdstudio --version` and the release workflow all read it).

## Commands you will need

```bash
make bootstrap        # xcodegen + openjdk@17 (once)
make core             # build the Kotlin XCFramework into macos/Frameworks (required before any Swift build)
make test-kotlin      # ./gradlew :core:macosArm64Test :cli:macosArm64Test
make test-unit        # Swift unit + bridge tests (no screenshots)
make test-swift       # Swift tests including screenshot tests
make test             # everything
make lint             # ktlint + swift format (what CI runs)
make format           # fix formatting in place
make app              # Release build of the app; make install copies it to /Applications
make record-snapshots # re-record screenshot references after an INTENTIONAL UI change
```

Direct equivalents: `./gradlew …` from the root, `swift test` from `macos/`. Always run from those directories.
CI (`.github/workflows/ci.yml`) runs lint, Kotlin tests, Swift unit/bridge tests and an Xcode build on every push.

## Rules

### Architecture

1. **Logic goes in `core/`, in Kotlin, with tests.** The Swift UI and the CLI only present it. If you find yourself
   parsing files or building shell commands in Swift, stop and move it to the core.
2. **`AVDStudioUI` must stay free of Kotlin.** Only `AVDStudioKit` imports `AVDStudioCore`. New data crossing the
   bridge gets a plain Swift value type in `AVDStudioUI/Models` and a mapping in `KotlinDeviceService.swift`.
3. **Everything the UI needs from the outside goes through the `DeviceService` protocol**, so it can be faked.
   Extend the protocol, the Kotlin implementation, `PreviewDeviceService` and the test `FakeDeviceService` together.
4. **Never run a shell to build commands.** `Command(executable, arguments)` passes arguments verbatim. The one
   accepted use of `/bin/sh -c` is `yes | sdkmanager --licenses`, and it passes paths as positional parameters.
5. **Explicit choices beat detection.** Every core function takes `sdkPathOverride` / `avdHomeOverride`; the CLI
   exposes them as `--sdk-path` / `--avd-home`; the app stores them in Settings. Keep that symmetry.
6. **The app never bundles or redistributes the Android SDK** and never accepts Google's licence on the user's
   behalf: the user ticks the box (app) or passes `--accept-licenses` (CLI) first.
7. **Network:** the only allowed outbound requests are to the GitHub Releases API (updates) and the asset downloads
   it points to. No analytics, no telemetry, ever.
8. Kotlin: `explicitApi()` and `allWarningsAsErrors` are on. Mark things `internal` unless Swift needs them.
   Swift: Swift 6 strict concurrency; models are `@MainActor @Observable`; Kotlin objects are not `Sendable`, so
   `KotlinDeviceService` does its work in `Task.detached` and returns value types only.

### Tests (non-negotiable)

- Every behaviour change ships with tests in the same commit. Core: `kotlin.test` with `FakeFileSystem` (Okio) and a
  recording `CommandRunner`; never touch the real `~/.android` or a real SDK. CLI: Clikt's `test()` against temp
  folders, with fake `brew`/`sdkmanager` shell scripts when execution matters. Swift: Swift Testing with
  `FakeDeviceService`; bridge tests use the real core against a temporary home with `HOMEBREW_PREFIX` redirected.
- Hermetic means hermetic: tests must pass on a Mac with and without an Android SDK, Java or Homebrew installed.
- Screenshot tests (`macos/Tests/AVDStudioSnapshotTests`) cover every screen in light and dark. When you change a
  view on purpose, run `make record-snapshots`, look at the PNGs, and commit them. Never re-record to make an
  unexpected diff go away; that is a bug report.
- Run `make lint` and the relevant test target before you claim something works. Paste real output, not intent.

### Changes that need a matching edit elsewhere

| If you change… | also update |
| --- | --- |
| anything a user can notice | `CHANGELOG.md` under `## [Unreleased]` (Keep a Changelog groups) |
| a dependency (`gradle/libs.versions.toml`, `macos/Package.swift`) | `LICENSES.md` |
| CLI options or commands | the command's `help`/`helpEpilog`, `docs/CLI.md` (and the short list in `README.md` if the command is shown there), CLI tests |
| a Settings option | `SettingsView`, the screenshot references, `docs/USER-GUIDE.md` (Settings) |
| install, update or uninstall behaviour | `docs/INSTALL.md` (and the Install section of `README.md`) |
| the setup/doctor commands | `Doctor` hints, `SetupPlanner`, the CLI `setup`/`doctor` output and both test suites |
| the app icon | run `make icon` (`scripts/generate-icon.swift` is the source; the PNGs are generated) |
| a GitHub Actions version | let Dependabot do it, or pin a real major tag you verified exists |

### Things not to do

- Do not commit `macos/Frameworks/`, `macos/AVDStudio.xcodeproj`, `macos/App/Info.plist` or any `build/` output;
  they are generated (see `.gitignore`).
- Do not edit `Casks/*.rb` versions/checksums by hand; `scripts/update-homebrew.sh` does it in CI.
- Do not add `macosX64`: Kotlin deprecated it and the app is Apple Silicon only.
- Do not add a `CNAME` file to `website/` or hard-code the production domain; see `website/README.md`.
- Do not add web fonts, CDNs or third-party scripts to the website (its CSP would block them anyway).
- Do not run `git push`, create tags or publish releases unless explicitly asked. `scripts/release.sh` is
  deliberately read-only about git: it prints the commands for a human to run. Releases are normally cut by the
  "Create release" workflow (`.github/workflows/tag.yml`, see `docs/RELEASING.md`).

## Conventions

- Commits: [Conventional Commits](https://www.conventionalcommits.org) (`feat(macos): …`, `fix(core): …`,
  `ci: …`, `docs: …`), imperative subject, body explains why. No generated-by/co-author trailers.
- Branch from `main`; one logical change per PR; keep screenshot re-records in their own commit when large.
- Language: English for code, comments, docs and UI strings. Sentence case in UI; Apple's terms (Settings, not
  Preferences; Menu bar; Finder).
- Formatting is enforced: ktlint (`.editorconfig`) and `swift format` (`.swift-format`). Run `make format`.

## Definition of done

1. `make lint` passes.
2. The tests that cover the change pass locally (`make test-kotlin`, `make test-unit`, and `make test-swift` when a
   view changed), and you looked at any new or changed screenshot.
3. `CHANGELOG.md` / `LICENSES.md` / `README.md` / the matching page in `docs/` updated per the table above.
4. The PR description says what changed, why, how it was tested, and includes before/after screenshots for UI.
