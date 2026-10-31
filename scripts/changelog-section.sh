#!/usr/bin/env bash
# Prints the body of one CHANGELOG.md section (used as the GitHub release notes).
# Usage: scripts/changelog-section.sh 0.2.0     (or "Unreleased")
set -euo pipefail

version="${1:?usage: changelog-section.sh <version|Unreleased>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

awk -v wanted="$version" '
  /^## \[/ {
    if (printing) exit
    name = $0
    sub(/^## \[/, "", name); sub(/\].*$/, "", name)
    if (name == wanted) { printing = 1; next }
  }
  printing { print }
' "$root/CHANGELOG.md" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
