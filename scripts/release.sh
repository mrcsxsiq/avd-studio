#!/usr/bin/env bash
# Prepares a release in the working tree: bumps VERSION and turns "Unreleased" in CHANGELOG.md into the new
# version. It never commits, tags or pushes; it prints the exact commands for you to review and run.
#
# Usage: scripts/release.sh <major.minor.patch[-prerelease]> [--dry-run]
set -euo pipefail

version="${1:?usage: release.sh <version> [--dry-run]}"
dry_run="${2:-}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

semver='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$'
[[ "$version" =~ $semver ]] || { echo "'$version' is not a valid semantic version (e.g. 0.2.0 or 1.0.0-rc.1)" >&2; exit 1; }

current="$(tr -d '[:space:]' < VERSION)"
# The very first release is allowed to keep the VERSION the project started with; any later one must change it.
grep -q "^## \[$version\]" CHANGELOG.md && { echo "CHANGELOG.md already has a section for $version (already released?)" >&2; exit 1; }
if [[ "$version" == "$current" ]] && grep -qE '^## \[[0-9]' CHANGELOG.md; then
  echo "VERSION is already $version and CHANGELOG.md has released versions: pick the next version" >&2
  exit 1
fi
[[ -n "$(scripts/changelog-section.sh Unreleased)" ]] || { echo "The Unreleased section of CHANGELOG.md is empty; nothing to release" >&2; exit 1; }

today="$(date +%Y-%m-%d)"
echo "Releasing $current -> $version ($today)"
if [[ "$dry_run" == "--dry-run" ]]; then
  echo "(dry run) would set VERSION and rewrite CHANGELOG.md. Release notes would be:"
  echo "-----"; scripts/changelog-section.sh Unreleased; echo "-----"
  exit 0
fi

echo "$version" > VERSION
python3 - "$version" "$today" <<'PY'
import re, sys
version, today = sys.argv[1], sys.argv[2]
text = open("CHANGELOG.md").read()
text = text.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## [{version}] - {today}\n", 1)
repo = "https://github.com/mrcsxsiq/avd-studio"
previous = re.search(r"^\[(\d[^\]]*)\]: .*$", text, re.M)
links = f"[Unreleased]: {repo}/compare/v{version}...HEAD\n[{version}]: {repo}/releases/tag/v{version}\n"
text = re.sub(r"^\[Unreleased\]: .*\n", links, text, count=1, flags=re.M)
open("CHANGELOG.md", "w").write(text)
PY

cat <<NEXT

Done. Review with: git diff
Then:
  git add VERSION CHANGELOG.md
  git commit -m "chore(release): $version"
  git tag -a v$version -m "AVD Studio $version"
  git push origin main v$version

Pushing the tag starts .github/workflows/release.yml (build, DMG, GitHub release, Homebrew update).
NEXT
