# Versioning

AVD Studio uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html), with the current version stored in the
root `VERSION` file. Gradle, the macOS app, the CLI, and release automation read that file; do not maintain separate
version numbers in build configuration or the Homebrew cask.

## Choosing a version

Versions use `MAJOR.MINOR.PATCH`:

- **Patch** (`0.4.0` → `0.4.1`): compatible bug fixes and small corrections.
- **Minor** (`0.4.0` → `0.5.0`): new user-facing capabilities that remain compatible.
- **Major** (`0.4.0` → `1.0.0`): incompatible changes or a deliberate stable 1.0 release.

While the major version is `0`, the public API and behavior may still change. Use judgment when choosing between a
patch and minor release, and describe notable changes in the changelog.

Pre-release identifiers such as `0.5.0-rc.1` are supported for release candidates. The in-app updater ignores GitHub
pre-releases, so use them for testing and do not treat them as the stable release.

## Version and changelog updates

- Add user-visible changes to `CHANGELOG.md` under `## [Unreleased]`, grouped by Added, Changed, Deprecated,
  Removed, Fixed, or Security.
- Do not bump `VERSION` for each feature pull request.
- When a release is ready and its PR has merged into `main`, run the **Create release** workflow with the chosen
  version. It checks CI, runs `scripts/release.sh`, commits the new `VERSION` and dated changelog section, and tags
  the commit.
- The release workflow builds the app and CLI, attaches the DMG and SHA-256 file, publishes the changelog as release
  notes, and updates the Homebrew cask version and checksum. Never edit the cask version or checksum manually.

The release tag has a `v` prefix (for example, version `0.5.0` is tagged `v0.5.0`). Keep the version in `VERSION`,
the changelog heading, release tag, and published assets aligned.
