#!/bin/bash

set -euo pipefail

XCFRAMEWORK_PATH="${1:-}"

if [[ -z "$XCFRAMEWORK_PATH" || ! -d "$XCFRAMEWORK_PATH" ]]; then
  echo "Usage: $0 /path/to/WebRTC.xcframework" >&2
  exit 2
fi

CAMERA_PATTERN='RTCCameraVideoCapturer|RTCCameraPreviewView|AVCaptureDevice|AVCaptureSession|AVCaptureVideoDataOutput|AVCaptureVideoPreviewLayer|AVMediaTypeVideo'
FOUND_SLICE=false

while IFS= read -r binary; do
  FOUND_SLICE=true
  echo "Auditing $binary"
  if strings -a "$binary" | grep -E "$CAMERA_PATTERN"; then
    echo "Camera API references remain in $binary" >&2
    exit 1
  fi
done < <(find "$XCFRAMEWORK_PATH" -type f -path '*/ios-*/*.framework/WebRTC' -print)

if [[ "$FOUND_SLICE" != "true" ]]; then
  echo "No iOS WebRTC framework slices found in $XCFRAMEWORK_PATH" >&2
  exit 1
fi

echo "No camera API references found in the iOS WebRTC slices."
