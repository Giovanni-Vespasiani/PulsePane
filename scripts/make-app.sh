#!/bin/bash
# Assembles MacPerformance.app from the SwiftPM-built binary (debug).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="${1:-debug}"
BUILD_DIR="$ROOT/.build/$CONFIG"
BIN="$BUILD_DIR/MacPerformance"
APP="$BUILD_DIR/MacPerformance.app"

if [[ ! -f "$BIN" ]]; then
  echo "error: binary not found at $BIN. Run 'swift build -c $CONFIG' first." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/MacPerformance"

# Minimal Info.plist: hides from Dock, arm64, high-res.
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MacPerformance</string>
    <key>CFBundleDisplayName</key>
    <string>MacPerformance</string>
    <key>CFBundleIdentifier</key>
    <string>local.MacPerformance</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleExecutable</key>
    <string>MacPerformance</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built: $APP"
