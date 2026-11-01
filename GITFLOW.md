# Gitflow

AVD Studio uses Gitflow with `main` as the production branch and `develop` as the integration branch. Changes reach
`main` through pull requests. Releases are built and published from `main` by the GitHub Actions release workflow.

## Branches

- `main` contains the latest released version. Do not push feature work directly to it.
- `develop` collects completed work for the next release. Feature pull requests target this branch.
- `feature/<short-name>` branches start from `develop` and merge back into `develop`.
- `release/<version>` branches start from `develop` when a release needs stabilization. Fixes on the release branch
  go into the release pull request; do not add unrelated features.
- `hotfix/<short-name>` branches start from `main` for urgent production fixes.

Use the repository's Conventional Commit format, for example `feat(macos): improve update status` or
`fix(core): handle missing SDK metadata`.

## Normal work

1. Update `develop` and branch from it: `git switch develop && git pull && git switch -c feature/<short-name>`.
2. Make one logical change, add tests and update `CHANGELOG.md` under `Unreleased` when users will notice it.
3. Open a pull request from the feature branch into `develop`. Wait for CI and review, then merge it.
4. Delete the merged feature branch.

## Release flow

1. Create `release/<version>` from `develop` when the release is ready for stabilization. Keep the version and release
   notes in `VERSION` and `CHANGELOG.md` unchanged on this branch: the **Create release** workflow owns that step.
2. Make release fixes on the release branch, with matching tests and changelog entries. Open a pull request into
   `main` and wait for CI and review.
3. After the release pull request is merged, run **Actions → Create release** with the chosen version. The workflow
   verifies CI on `main`, moves `Unreleased` into the dated version section in `CHANGELOG.md`, commits `VERSION` and
   the changelog, creates the annotated tag, builds and publishes the GitHub release, and updates Homebrew.
4. Merge the release branch into `develop` (or otherwise bring all its commits into `develop`) so release fixes are
   present in future work. Also sync the release commit and the automated Homebrew cask update from `main` into
   `develop`.
5. Delete the release branch after both branches contain the release changes.

The workflow must be run only after the release pull request has merged. Do not create or push release tags by hand.
See [docs/RELEASING.md](docs/RELEASING.md) for release checks and assets.

## Hotfix flow

1. Branch `hotfix/<short-name>` from `main`, make the smallest safe fix, add tests and a changelog entry.
2. Open a pull request into `main`. After CI and review, merge it and run **Create release** with the next patch
   version.
3. After the release workflow completes, merge `main` into `develop` so the fix and automated release and Homebrew
   commits are present in future work. The repository deletes the hotfix PR branch automatically after its merge.

## Pull request targets

| Branch pattern | Base branch |
| --- | --- |
| `feature/*` | `develop` |
| `release/*` | `main` |
| `hotfix/*` | `main` |

Keep pull requests focused, use the repository PR template, and wait for required CI checks before merging.
