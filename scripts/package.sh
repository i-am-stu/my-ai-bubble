#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/My AI Bubble.app"
[ -x "$APP/Contents/MacOS/MyAIBubble" ] || "$ROOT/scripts/build.sh"
codesign --verify --strict "$APP"
mkdir -p "$ROOT/dist"
STAGE=$(mktemp -d /private/tmp/my-ai-bubble-package.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
IMAGE="${STAGE}.dmg"
trap 'rm -rf "$STAGE"; rm -f "$IMAGE"' EXIT
mkdir "$STAGE/content"
ditto "$APP" "$STAGE/content/My AI Bubble.app"
ln -s /Applications "$STAGE/content/Applications"
cp "$ROOT/INSTALL.txt" "$STAGE/content/READ ME.txt"
hdiutil create -volname "My AI Bubble" -srcfolder "$STAGE/content" -fs HFS+ -ov -format UDZO "$IMAGE"
hdiutil verify "$IMAGE"
cp "$IMAGE" "$ROOT/dist/My-AI-Bubble.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/My-AI-Bubble.zip"
(cd "$ROOT/dist" && shasum -a 256 My-AI-Bubble.dmg My-AI-Bubble.zip > SHA256SUMS.txt)
printf 'Packaged: %s\n' "$ROOT/dist/My-AI-Bubble.dmg"
