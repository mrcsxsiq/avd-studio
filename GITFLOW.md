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

Every commit in a pull request must have a signature GitHub verifies. The **Signed commits** CI check inspects each
commit on the PR; unsigned or unverifiable commits fail the check. Configure GPG or SSH commit signing with the key
registered on your GitHub account before pushing.

## Merged branches are deleted

The repository has **Automatically delete head branches** turned on, so GitHub deletes a pull request's branch the
moment the pull request merges. That covers every `feature/*`, `release/*` and `hotfix/*` branch, and the branches of
documentation and Dependabot pull requests too.

- Do not reuse a merged branch or its name. Start a new branch from the current `develop` (from `main` for a hotfix).
- Never use `develop` or `main` as the head branch of a pull request. GitHub deletes the head branch of a merged pull
  request unless the branch is protected, so merging a pull request *from* `develop` would delete `develop`. To bring
  `main` into `develop`, open the pull request from `main`, which cannot be deleted.
- Clean up locally after each merge: `git switch develop && git pull --prune`, then
  `git branch -d feature/<short-name>`. If you used a worktree, remove it too: `git worktree remove <path>`.
- A branch deleted too soon can be restored from its closed pull request ("Restore branch").

## Normal work

1. Update `develop` and branch from it: `git switch develop && git pull && git switch -c feature/<short-name>`.
2. Make one logical change, add tests and update `CHANGELOG.md` under `Unreleased` when users will notice it.
3. Open a pull request from the feature branch into `develop`. Wait for CI and review, then merge it.
4. The merged feature branch is deleted automatically; delete your local copy (see above).

## Release flow

1. Create `release/<version>` from `develop` when the release is ready for stabilization. Keep the version and release
   notes in `VERSION` and `CHANGELOG.md` unchanged on this branch: the **Create release** workflow owns that step.
2. Make release fixes on the release branch, with matching tests and changelog entries. Open a pull request into
   `main` and wait for CI and review.
3. After the release pull request is merged, run **Actions → Create release** with the chosen version. The workflow
   verifies CI on `main`, moves `Unreleased` into the dated version section in `CHANGELOG.md`, commits `VERSION` and
   the changelog, creates the annotated tag, builds and publishes the GitHub release, and updates Homebrew.
4. Bring the release back into `develop`: open a pull request **from `main` into `develop`** and merge it with a merge
   commit (not a squash), so the release fixes, the release commit and the automated Homebrew cask update are present
   in future work.
5. The release branch was deleted automatically when its pull request merged into `main`; there is nothing to clean up
   on GitHub. Delete your local copy.

The workflow must be run only after the release pull request has merged. Do not create or push release tags by hand.
See [docs/RELEASING.md](docs/RELEASING.md) for release checks and assets.

## Hotfix flow

1. Branch `hotfix/<short-name>` from `main`, make the smallest safe fix, add tests and a changelog entry.
2. Open a pull request into `main`. After CI and review, merge it and run **Create release** with the next patch
   version.
3. After the release workflow completes, open a pull request **from `main` into `develop`** and merge it with a merge
   commit, so the fix and the automated release and Homebrew commits are present in future work. The hotfix branch
   was deleted automatically when its pull request merged.

## Pull request targets

| Branch pattern | Base branch |
| --- | --- |
| `feature/*` | `develop` |
| `release/*` | `main` |
| `hotfix/*` | `main` |
| `dependabot/*` | `develop` (set by `target-branch` in `.github/dependabot.yml`) |

Keep pull requests focused, use the repository PR template, and wait for required CI checks before merging.
