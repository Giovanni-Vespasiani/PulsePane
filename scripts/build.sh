#!/bin/bash
# Build PulsePane release .app (build + bundle assembly).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIG="${1:-release}"

swift build -c "$CONFIG" --package-path "$SCRIPT_DIR/.."

"$SCRIPT_DIR/make-app.sh" "$CONFIG"