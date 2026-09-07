#!/bin/bash
# Assembles PulsePane.app from the SwiftPM-built binary (debug).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="${1:-debug}"

# Find the built binary (SwiftPM uses platform-specific build directory)
# Exclude binaries already inside .app bundles to avoid nested app creation
BUILD_DIR="$ROOT/.build"
BIN=$(find "$BUILD_DIR" -name "PulsePane" -type f -path "*/$CONFIG/*" -perm +111 2>/dev/null | grep -v "\.app/" | head -n1)
BIN_DIR=$(dirname "$BIN")
APP="$BIN_DIR/PulsePane.app"

if [[ ! -f "$BIN" ]]; then
  echo "error: binary not found for config '$CONFIG'. Run 'swift build -c $CONFIG' first." >&2
  exit 1
fi

# Remove any existing app to avoid nested app creation
rm -rf "$APP"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/PulsePane"

# Minimal Info.plist: hides from Dock, arm64, high-res.
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PulsePane</string>
    <key>CFBundleDisplayName</key>
    <string>PulsePane</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.Giovanni-Vespasiani.PulsePane</string>
    <key>CFBundleVersion</key>
    <string>2.3.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.3.0</string>
    <key>CFBundleExecutable</key>
    <string>PulsePane</string>
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