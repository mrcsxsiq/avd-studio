# Security policy

## Supported versions

Only the latest release gets security fixes. The app checks for updates and tells you when one is available.

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Use GitHub's private vulnerability reporting instead:
**https://github.com/mrcsxsiq/avd-studio/security/advisories/new**

Include what you found, how to reproduce it, and which version (app or CLI, `avdstudio --version`) you tested.
You should hear back within a week. Once the fix is released you will be credited in the changelog unless you
prefer not to be.

## What is in scope

- The macOS app and the `avdstudio` command-line tool.
- The update mechanism (the app downloads a DMG from GitHub Releases and verifies its SHA-256 against the
  `.sha256` file published next to it).
- The one-click setup, which runs `brew` and `sdkmanager` on the user's Mac.
- The release workflow and the Homebrew files in this repository.

Out of scope: the Android SDK tools and emulator themselves (report those to Google), and Homebrew.

## Design notes relevant to security

- Commands are started with explicit executable paths and argument lists; no shell interpolation of user data.
- The app never asks for or stores credentials, and has no account system.
- The only network requests are to `api.github.com` and the GitHub release asset URLs, over HTTPS.
- Releases are built by GitHub Actions from a tag; when the signing secrets are configured the app and DMG are
  Developer ID signed and notarized. Checksums of every asset are published with the release.
