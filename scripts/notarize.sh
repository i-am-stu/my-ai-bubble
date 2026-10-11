#!/bin/bash
set -euo pipefail
: "${NOTARY_PROFILE:?Set the notarytool Keychain profile name}"
TARGET="${1:?Provide an app or DMG path}"
STAGE=$(mktemp -d /private/tmp/my-ai-bubble-notary.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
UPLOAD="$TARGET"
if [[ "$TARGET" == *.app ]]; then
  UPLOAD="$STAGE/submission.zip"
  ditto -c -k --sequesterRsrc --keepParent "$TARGET" "$UPLOAD"
fi
xcrun notarytool submit "$UPLOAD" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$STAGE/result.json"
/usr/bin/plutil -extract status raw -o "$STAGE/status" "$STAGE/result.json"
if [[ "$(cat "$STAGE/status")" != "Accepted" ]]; then
  cat "$STAGE/result.json"
  exit 1
fi
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"
if [[ "$TARGET" == *.app ]]; then
  spctl --assess --type execute --verbose=2 "$TARGET"
else
  spctl --assess --type open --context context:primary-signature --verbose=2 "$TARGET"
fi
