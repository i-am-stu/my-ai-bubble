#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/My AI Bubble.app"
"$ROOT/scripts/build.sh"
codesign --verify --strict "$APP"
mkdir -p "$ROOT/dist"
STAGE=$(mktemp -d /private/tmp/my-ai-bubble-package.XXXXXX)
MOUNT="$STAGE/mount"
cleanup() {
  if mount | grep -Fq " on $MOUNT "; then hdiutil detach "$MOUNT" || return; fi
  rm -rf "$STAGE"
}
trap cleanup EXIT
mkdir "$MOUNT"
# Explicit mounting avoids intermittent srcfolder Resource busy failures.
hdiutil create -size 20m -fs HFS+ -volname "My AI Bubble" "$STAGE/writable.dmg"
hdiutil attach -nobrowse -mountpoint "$MOUNT" "$STAGE/writable.dmg"
ditto "$APP" "$MOUNT/My AI Bubble.app"
ln -s /Applications "$MOUNT/Applications"
cp "$ROOT/INSTALL.txt" "$MOUNT/READ ME.txt"
cp "$ROOT/LICENSE" "$MOUNT/LICENSE.txt"
codesign --verify --strict "$MOUNT/My AI Bubble.app"
hdiutil detach "$MOUNT"
hdiutil convert "$STAGE/writable.dmg" -format UDZO -o "$STAGE/My-AI-Bubble.dmg"
hdiutil verify "$STAGE/My-AI-Bubble.dmg"
cp "$STAGE/My-AI-Bubble.dmg" "$ROOT/dist/My-AI-Bubble.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/My-AI-Bubble.zip"
(cd "$ROOT/dist" && shasum -a 256 My-AI-Bubble.dmg My-AI-Bubble.zip > SHA256SUMS.txt)
printf 'Packaged: %s\n' "$ROOT/dist/My-AI-Bubble.dmg"
