#!/usr/bin/env bash
# Packages AVD Studio.app into a compressed DMG with an /Applications shortcut (drag to install).
# Usage: scripts/package-dmg.sh "path/to/AVD Studio.app" out/AVD-Studio-0.1.0.dmg
set -euo pipefail

app="${1:?usage: package-dmg.sh <app> <output.dmg>}"
output="${2:?usage: package-dmg.sh <app> <output.dmg>}"
[[ -d "$app" ]] || { echo "No such app: $app" >&2; exit 1; }

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# ditto keeps symlinks, extended attributes and the code signature intact (cp -R does not).
ditto "$app" "$stage/$(basename "$app")"
ln -s /Applications "$stage/Applications"

mkdir -p "$(dirname "$output")"
rm -f "$output"
hdiutil create -volname "AVD Studio" -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$output" >/dev/null
echo "Created $output ($(du -h "$output" | cut -f1))"
