#!/bin/bash
# Run MacPerformance (must already be built).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$ROOT/.build/debug/MacPerformance.app"
CONFIG="${1:-debug}"

if [[ "$CONFIG" == "release" ]]; then
  APP="$ROOT/.build/release/MacPerformance.app"
fi

if [[ ! -d "$APP" ]]; then
  echo "error: app not found at $APP. Run scripts/build.sh $CONFIG first." >&2
  exit 1
fi

open "$APP"
