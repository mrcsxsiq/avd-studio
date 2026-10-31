#!/usr/bin/env bash
# Packages the release CLI as avdstudio-<version>-macos-arm64.tar.gz.
# Usage: scripts/package-cli.sh <version> <output-dir>   (run `make cli` first)
set -euo pipefail

version="${1:?usage: package-cli.sh <version> <output-dir>}"
out="${2:?usage: package-cli.sh <version> <output-dir>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="$root/cli/build/bin/macosArm64/releaseExecutable/avdstudio.kexe"
[[ -x "$binary" ]] || { echo "Release CLI not built. Run: make cli" >&2; exit 1; }

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$binary" "$stage/avdstudio"
cp "$root/LICENSE" "$stage/LICENSE"

mkdir -p "$out"
archive="$out/avdstudio-$version-macos-arm64.tar.gz"
tar -czf "$archive" -C "$stage" avdstudio LICENSE
echo "Created $archive"
