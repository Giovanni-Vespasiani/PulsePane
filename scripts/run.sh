#!/bin/bash
# Run PulsePane (must already be built).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="${1:-release}"
APP="$ROOT/.build/$CONFIG/PulsePane.app"

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found. Run './scripts/build.sh $CONFIG' first." >&2
  exit 1
fi

open "$APP"