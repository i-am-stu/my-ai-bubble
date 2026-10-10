# Public-release review — 10 October 2026

Scope: version 1.23.1 runtime source, build/test/package scripts, app metadata, documentation, all seven existing Git commits (32 distinct file objects), and the universal release binary. This is an AI-assisted source and release review, not an independent security audit or legal opinion.

## Findings and changes

- Bundled the MIT copyright and licence notice inside the app and on the disk image. Earlier binaries predated the licence file.
- Packaging now rebuilds from current source rather than silently reusing an old executable.
- Saved app choices are checked for executable application bundles, deduplicated and limited to ten. Launch targets are checked again before opening.
- Invalid saved coordinates and stale removal indices are handled without crashing.
- Very small repeated drag movements no longer accidentally count as a click at release.
- Added creator attribution, local-data documentation and private vulnerability reporting.

No critical or high-severity issue was identified in this review. That is not a guarantee that none exists.

## Checks

- Full runtime read: no network requests, shell execution, downloaded code, credential handling, chat scraping, notification monitoring, privileged helpers or automatic updates found.
- No third-party runtime packages; the binary links system frameworks and Swift libraries. No app entitlements are embedded; the app is not sandboxed.
- Pattern scan of all existing textual Git objects for common tokens, private keys, credential assignments and private home paths: no matches. This is a limited pattern scan, not proof of absence. GitHub secret scanning returned zero alerts at review time; push protection is enabled.
- Regression checks passed for 0/1/6/10 app layouts, exact centre drag release, reorder identity and persistence, folding and reversals, hidden click targets, Reduce Motion and artwork loading.
- Added checks for invalid/duplicate launch targets, ten-app limit, non-finite coordinates and invalid removal indices.
- Apple silicon and Intel compilation passed; app signature verification and property-list validation passed.

## Remaining limits

- No Apple Developer ID signature, notarisation or App Sandbox isolation. Users must trust the publisher and selected apps. The launcher does not make other apps safe.
- Intel hardware, a fresh Mac installation and the full macOS 13+ version range have not been tested. VoiceOver, prolonged resource use and all multi-monitor/Space combinations have not been exhaustively tested.
- The centre animation performs regular rendering and uses some CPU/GPU power. Reduce Motion disables the changing artwork.
- The public preview includes third-party app logos. Attribution is not legal clearance; the MIT licence does not grant rights to third-party names or logos. Ownership and licensing of supplied artwork have not been independently verified.
- GitHub author attribution is intentionally public. Local app paths and preferences are not shipped in the release.

Future releases should repeat these checks, verify the mounted download, and test on a clean Mac before wider distribution.
