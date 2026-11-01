#!/usr/bin/env bash
# Points Casks/avd-studio.rb at a new release. The command-line tool ships inside the app, so the cask is the
# only Homebrew artifact (it links `avdstudio` into the PATH with a `binary` stanza).
# Usage: scripts/update-homebrew.sh <version> <dmg-sha256>
set -euo pipefail

version="${1:?usage: update-homebrew.sh <version> <dmg-sha256>}"
dmg_sha="${2:?missing dmg sha256}"
[[ "$dmg_sha" =~ ^[0-9a-f]{64}$ ]] || { echo "'$dmg_sha' is not a lowercase sha256" >&2; exit 1; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cask="$root/Casks/avd-studio.rb"

sed -i '' -E "s/^  version \".*\"/  version \"$version\"/; s/^  sha256 \".*\"/  sha256 \"$dmg_sha\"/" "$cask"
grep -q 'Contents/Helpers/avdstudio' "$cask" || { echo "The cask lost its binary stanza" >&2; exit 1; }
ruby -c "$cask" > /dev/null
echo "Homebrew cask now points at $version"
