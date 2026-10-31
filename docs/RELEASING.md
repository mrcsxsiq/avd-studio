# Releasing

Releases are cut from `main` by pushing a tag. Everything else (building, packaging, signing, publishing, updating
Homebrew) is done by `.github/workflows/release.yml`.

## 1. Prepare

1. Make sure `CHANGELOG.md` has everything under `## [Unreleased]`; that text becomes the release notes.
2. Pick the version with [SemVer](https://semver.org): `MAJOR` for breaking changes (for a desktop app: removed
   features or settings that no longer carry over), `MINOR` for new features, `PATCH` for fixes.
   Pre-releases look like `1.0.0-rc.1` and are published as GitHub pre-releases (the in-app updater ignores them).
3. Run the release script; it only edits files and prints the git commands:

   ```bash
   scripts/release.sh 0.2.0 --dry-run   # shows the notes that will be published
   scripts/release.sh 0.2.0             # writes VERSION, moves Unreleased -> [0.2.0] - <date>
   git diff                             # review
   ```

## 2. Tag and push

```bash
git add VERSION CHANGELOG.md
git commit -m "chore(release): 0.2.0"
git tag -a v0.2.0 -m "AVD Studio 0.2.0"
git push origin main v0.2.0
```

## 3. What the workflow does

1. Checks that the tag matches `VERSION`.
2. Builds the Kotlin core and the release CLI, generates the Xcode project and builds the app (Release, arm64).
3. If the signing secrets exist: signs the app with Developer ID and hardened runtime.
4. Packages `AVD-Studio-<version>.dmg` (drag-to-Applications) and `avdstudio-<version>-macos-arm64.tar.gz`.
5. If the signing secrets exist: signs the DMG, submits it to Apple's notary service and staples the ticket.
6. Writes a `.sha256` next to every asset (the in-app updater verifies the DMG against it).
7. Creates the GitHub release with the matching `CHANGELOG.md` section as notes.
8. Updates `Casks/avd-studio.rb` and `Formula/avdstudio.rb` with the new version and checksums and pushes that
   commit to `main` (`chore(homebrew): <version>`).

Watch it under **Actions → Release**. If it fails, fix the cause, delete the tag (`git push --delete origin v0.2.0`
and `git tag -d v0.2.0`) and push it again; nothing is published until step 7.

## 4. Check

- Open the release page: DMG, tarball and `.sha256` files are attached, notes look right.
- Install the DMG on a clean user account: the app opens (without a warning once notarized), Settings →
  Updates shows the new version.
- `brew upgrade --cask avd-studio` / `brew upgrade avdstudio` from the tap pick up the new version.
- The website's download button shows the new version (it reads the GitHub API).

## Signing and notarization secrets

Without them the workflow still produces a working, ad-hoc-signed app; macOS will warn on first launch
(right-click → Open). To ship properly signed builds add these repository secrets:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE` | Your **Developer ID Application** certificate exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PASSWORD` | The `.p12` password |
| `APPLE_ID` | The Apple ID of the developer account |
| `APPLE_TEAM_ID` | The 10-character team id |
| `APPLE_APP_PASSWORD` | An [app-specific password](https://support.apple.com/HT204397) for `notarytool` |

The signing step is skipped when `MACOS_CERTIFICATE` is empty, so it is safe to set them up later.
`scripts/sign-and-notarize.sh` has not been exercised by this repository's CI yet; test the first signed release
on a tag like `v0.2.0-rc.1`.

## Homebrew tap

This repository doubles as the tap. Users run:

```bash
brew tap mrcsxsiq/avd-studio https://github.com/mrcsxsiq/avd-studio
brew install --cask avd-studio    # the app
brew install avdstudio            # the CLI
```

`Casks/avd-studio.rb` and `Formula/avdstudio.rb` point at the GitHub release assets. Never edit their `version` and
`sha256` by hand; the workflow calls `scripts/update-homebrew.sh`.

## Version bump checklist (humans and agents)

- [ ] `CHANGELOG.md` Unreleased section is complete and in user language
- [ ] `LICENSES.md` matches the current dependencies
- [ ] `make lint && make test` are green locally
- [ ] `scripts/release.sh <version>` run and the diff reviewed
- [ ] commit + annotated tag pushed, workflow green, release page checked
