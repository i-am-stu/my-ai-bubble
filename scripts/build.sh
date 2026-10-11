#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/My AI Bubble.app"
mkdir -p "$BUILD/arm64" "$BUILD/x86_64" "$APP/Contents/MacOS" "$APP/Contents/Resources"
for ARCH in arm64 x86_64; do
  xcrun swiftc "$ROOT/Sources/MyAIBubble.swift" -target "${ARCH}-apple-macos13.0" -framework Cocoa -framework CoreImage -O -o "$BUILD/$ARCH/MyAIBubble"
done
xcrun lipo -create "$BUILD/arm64/MyAIBubble" "$BUILD/x86_64/MyAIBubble" -output "$APP/Contents/MacOS/MyAIBubble"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/BubbleArtwork.png" "$ROOT/Resources/MyAIBubble.icns" "$APP/Contents/Resources/"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$APP"
