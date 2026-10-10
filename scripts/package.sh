#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/My AI Bubble.app"
[ -x "$APP/Contents/MacOS/MyAIBubble" ] || "$ROOT/scripts/build.sh"
codesign --verify --strict "$APP"
mkdir -p "$ROOT/dist"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/My-AI-Bubble.zip"
(cd "$ROOT/dist" && shasum -a 256 My-AI-Bubble.zip > SHA256SUMS.txt)
printf 'Packaged: %s\n' "$ROOT/dist/My-AI-Bubble.zip"
