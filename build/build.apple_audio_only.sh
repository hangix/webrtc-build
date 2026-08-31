#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT="${1:-}"
MODE="${2:-release}"

cd "$SCRIPT_DIR"
python3 run.py build apple_audio_only --commit "$COMMIT" --webrtc-fetch

export PATH="$SCRIPT_DIR/_source/apple_audio_only/depot_tools:$PATH"
mkdir -p "$SCRIPT_DIR/_package/apple_audio_only"
"$SCRIPT_DIR/apple/xcframework_ios_only.sh" \
  "$MODE" \
  "$SCRIPT_DIR/_source/apple_audio_only/webrtc/src" \
  "$SCRIPT_DIR/_package/apple_audio_only"

"$SCRIPT_DIR/apple/audit_no_camera.sh" \
  "$SCRIPT_DIR/_package/apple_audio_only/WebRTC.xcframework"
