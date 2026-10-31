#!/usr/bin/env bash
# Generates macos/AVDStudio.xcodeproj from macos/project.yml (the .xcodeproj is not committed).
# The version comes from the VERSION file so there is a single source of truth.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MARKETING_VERSION="${MARKETING_VERSION:-$(tr -d '[:space:]' < "$root/VERSION")}"
export BUILD_NUMBER="${BUILD_NUMBER:-1}"

command -v xcodegen >/dev/null || { echo "xcodegen is required: brew install xcodegen" >&2; exit 1; }
[[ -d "$root/macos/Frameworks/AVDStudioCore.xcframework" ]] || {
  echo "Kotlin core not built yet. Run: make core" >&2
  exit 1
}

cd "$root/macos"
xcodegen generate --quiet
echo "Generated macos/AVDStudio.xcodeproj (version $MARKETING_VERSION, build $BUILD_NUMBER)"
