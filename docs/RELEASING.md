# Releasing

Releases are cut from `main` by pushing a tag. Everything else (building, packaging, signing, publishing, updating
Homebrew) is done by `.github/workflows/release.yml`.

## The short way: the "Create release" workflow

**Actions → Create release → Run workflow**, type the version (for example `0.2.0`) and run it. Tick *dry run* first
to see the release notes and have every check run without changing anything. The workflow:

1. validates the version, refuses a tag that already exists, and requires a green CI run on the latest commit of `main`;
2. runs `scripts/release.sh` (writes `VERSION`, moves `Unreleased` to the new version in `CHANGELOG.md`),
   commits that as `chore(release): <version>` and creates the annotated tag, pushing both **atomically**;
3. calls the release workflow below, which builds and publishes. (A tag pushed with the default `GITHUB_TOKEN` does
   not trigger other workflows, which is why the tag workflow calls the release one directly.)

From the command line: `gh workflow run tag.yml -f version=0.2.0` (add `-f dry_run=true` to rehearse).
The very first release (`0.1.0`) works too: `VERSION` already says 0.1.0 and `release.sh` only moves the changelog.

The manual way, step by step, is below; use it if you want to review the diff before anything is pushed.

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
4. Packages `AVD-Studio-<version>.dmg` (drag-to-Applications). The CLI ships inside the app, so there is no separate CLI archive.
5. If the signing secrets exist: signs the DMG, submits it to Apple's notary service and staples the ticket.
6. Writes a `.sha256` next to every asset (the in-app updater verifies the DMG against it).
7. Creates the GitHub release with the matching `CHANGELOG.md` section as notes.
8. Updates `Casks/avd-studio.rb` with the new version and checksum and pushes that
   commit to `main` (`chore(homebrew): <version>`).

Watch it under **Actions → Release**. If it fails, fix the cause, delete the tag (`git push --delete origin v0.2.0`
and `git tag -d v0.2.0`) and push it again; nothing is published until step 7.

## 4. Check

- Open the release page: the DMG and its `.sha256` file are attached, notes look right.
- Install the DMG on a clean user account: the app opens (without a warning once notarized), Settings →
  Updates shows the new version.
- `brew upgrade --cask avd-studio` from the tap picks up the new version (on a Mac that trusted it), and `avdstudio --version` runs.
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

This repository doubles as the tap, so it is added with its URL. Homebrew 6.0 and later load casks and formulae
from non-official taps only after you trust them ([Tap Trust](https://docs.brew.sh/Tap-Trust)). Installing by the
fully qualified name trusts just that item, which is the form we document:

```bash
brew tap mrcsxsiq/avd-studio https://github.com/mrcsxsiq/avd-studio
brew install --cask mrcsxsiq/avd-studio/avd-studio    # the app and the avdstudio command
```

The cask's `binary` stanza links `AVD Studio.app/Contents/Helpers/avdstudio` into the PATH, so there is no separate
CLI formula (0.1.0 had one; 0.2.0 removed it). Its `postflight_steps` block clears the quarantine flag, because
Gatekeeper kills the bundled CLI of an un-notarized, quarantined app (exit 137). **Delete that block when releases
are notarized.**

The short name (`brew install --cask avd-studio`) needs the cask trusted first:
`brew trust --cask mrcsxsiq/avd-studio/avd-studio` (or `brew trust --tap mrcsxsiq/avd-studio` for the whole tap). Keep this in mind when you answer "brew can't find
the cask" issues: the usual cause is a missing `brew tap` URL or missing trust.

`Casks/avd-studio.rb` points at the GitHub release assets. Never edit its `version` and
`sha256` by hand; the workflow calls `scripts/update-homebrew.sh`.

## Version bump checklist (humans and agents)

- [ ] `CHANGELOG.md` Unreleased section is complete and in user language
- [ ] `LICENSES.md` matches the current dependencies
- [ ] `make lint && make test` are green locally
- [ ] `scripts/release.sh <version>` run and the diff reviewed
- [ ] commit + annotated tag pushed, workflow green, release page checked
