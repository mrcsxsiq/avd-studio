#!/usr/bin/env bash
# Points Casks/avd-studio.rb and Formula/avdstudio.rb at a new release.
# Usage: scripts/update-homebrew.sh <version> <dmg-sha256> <cli-sha256>
set -euo pipefail

version="${1:?usage: update-homebrew.sh <version> <dmg-sha256> <cli-sha256>}"
dmg_sha="${2:?missing dmg sha256}"
cli_sha="${3:?missing cli sha256}"
for sha in "$dmg_sha" "$cli_sha"; do
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "'$sha' is not a lowercase sha256" >&2; exit 1; }
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sed -i '' -E "s/^  version \".*\"/  version \"$version\"/; s/^  sha256 \".*\"/  sha256 \"$dmg_sha\"/" "$root/Casks/avd-studio.rb"
sed -i '' -E "s/^  version \".*\"/  version \"$version\"/; s/^  sha256 \".*\"/  sha256 \"$cli_sha\"/" "$root/Formula/avdstudio.rb"
for file in "$root/Casks/avd-studio.rb" "$root/Formula/avdstudio.rb"; do ruby -c "$file" >/dev/null; done
echo "Homebrew files now point at $version"
