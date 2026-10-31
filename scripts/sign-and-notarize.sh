#!/usr/bin/env bash
# Developer ID signing and notarization for the release workflow. It only runs when the secrets exist.
# NOT exercised by this repository's CI until you add them (see docs/RELEASING.md), so treat it as untested.
#
# The order matters: sign the app, THEN build the DMG from it, THEN sign and notarize the DMG.
#   scripts/sign-and-notarize.sh sign-app "path/to/AVD Studio.app"
#   scripts/sign-and-notarize.sh notarize-dmg path/to/AVD-Studio-0.1.0.dmg
#
# Environment:
#   MACOS_CERTIFICATE            base64 of your "Developer ID Application" .p12
#   MACOS_CERTIFICATE_PASSWORD   its password
#   APPLE_ID, APPLE_TEAM_ID      your Apple developer account
#   APPLE_APP_PASSWORD           an app-specific password for notarytool
#   RUNNER_TEMP                  scratch directory (set by GitHub Actions)
set -euo pipefail

command="${1:?usage: sign-and-notarize.sh sign-app <app> | notarize-dmg <dmg>}"
target="${2:?missing path}"
keychain="${RUNNER_TEMP:?RUNNER_TEMP must be set}/signing.keychain-db"

find_identity() {
  security find-identity -v -p codesigning "$keychain" | awk -F'"' '/Developer ID Application/ {print $2; exit}'
}

case "$command" in
  sign-app)
    password="$(uuidgen)"
    echo "$MACOS_CERTIFICATE" | base64 --decode > "$RUNNER_TEMP/certificate.p12"
    security create-keychain -p "$password" "$keychain"
    security set-keychain-settings -lut 21600 "$keychain"
    security unlock-keychain -p "$password" "$keychain"
    security import "$RUNNER_TEMP/certificate.p12" -P "$MACOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
    security set-key-partition-list -S apple-tool:,apple: -k "$password" "$keychain" > /dev/null
    security list-keychains -d user -s "$keychain" login.keychain-db
    rm -f "$RUNNER_TEMP/certificate.p12"

    identity="$(find_identity)"
    [[ -n "$identity" ]] || { echo "No Developer ID Application identity in the certificate" >&2; exit 1; }
    codesign --force --deep --options runtime --timestamp --sign "$identity" "$target"
    codesign --verify --deep --strict "$target"
    ;;
  notarize-dmg)
    identity="$(find_identity)"
    [[ -n "$identity" ]] || { echo "Run sign-app first (no identity in the keychain)" >&2; exit 1; }
    codesign --force --timestamp --sign "$identity" "$target"
    xcrun notarytool submit "$target" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
    xcrun stapler staple "$target"
    xcrun stapler validate "$target"
    ;;
  *)
    echo "unknown command: $command" >&2
    exit 2
    ;;
esac
