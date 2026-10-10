#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTAPP="$ROOT/build/BehaviourChecks.app"
mkdir -p "$TESTAPP/Contents/MacOS" "$TESTAPP/Contents/Resources"
awk '/^let app = NSApplication.shared$/ {exit} {print}' "$ROOT/Sources/MyAIBubble.swift" | sed 's/let defaults = UserDefaults.standard/let defaults = UserDefaults(suiteName: "local.myaibubble.behaviour-tests")!/' > "$ROOT/build/BehaviourChecks.swift"
cat "$ROOT/Tests/Behaviour.swift" >> "$ROOT/build/BehaviourChecks.swift"
cp "$ROOT/Resources/BubbleArtwork.png" "$TESTAPP/Contents/Resources/"
xcrun swiftc "$ROOT/build/BehaviourChecks.swift" -framework Cocoa -framework CoreImage -o "$TESTAPP/Contents/MacOS/BehaviourChecks"
"$TESTAPP/Contents/MacOS/BehaviourChecks" "$ROOT/build/test-preview.png"
