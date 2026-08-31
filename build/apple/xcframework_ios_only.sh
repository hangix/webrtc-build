#!/bin/bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 'debug'|'release' source_dir out_dir [prefix]" >&2
  exit 2
fi

MODE="$1"
SOURCE_DIR="$(realpath "$2")"
mkdir -p "$3"
OUT_DIR="$(realpath "$3")"
PREFIX="${4:-}"

if [[ -z "$PREFIX" ]]; then
  FRAMEWORK_NAME="WebRTC"
else
  FRAMEWORK_NAME="${PREFIX}WebRTC"
fi

DEBUG=false
if [[ "$MODE" == "debug" ]]; then
  DEBUG=true
elif [[ "$MODE" != "release" ]]; then
  echo "Mode must be 'debug' or 'release'." >&2
  exit 2
fi

PARALLEL_BUILDS="${WEBRTC_PARALLEL_BUILDS:-6}"

start_group() {
  if [[ "${CI:-}" == "true" ]]; then
    echo "::group::$1"
  else
    echo "=== $1 ==="
  fi
}

end_group() {
  if [[ "${CI:-}" == "true" ]]; then
    echo "::endgroup::"
  fi
}

COMMON_ARGS="
      enable_dsyms = $DEBUG
      enable_libaom = true
      enable_stripping = true
      ios_enable_code_signing = false
      is_component_build = false
      is_debug = $DEBUG
      rtc_build_examples = false
      rtc_enable_protobuf = false
      rtc_enable_symbol_export = true
      rtc_include_dav1d_in_internal_decoder_factory = true
      rtc_include_tests = false
      rtc_libvpx_build_vp9 = true
      rtc_use_h264 = false
      treat_warnings_as_errors = true
      use_rtti = true"

# Intouch ships only on iOS. The device slice is required by App Store builds;
# the arm64 simulator slice supports development on Apple Silicon Macs.
PLATFORMS=(
  "iOS-arm64-device:target_os=\"ios\" target_environment=\"device\" target_cpu=\"arm64\" ios_deployment_target=\"13.0\""
  "iOS-arm64-simulator:target_os=\"ios\" target_environment=\"simulator\" target_cpu=\"arm64\" ios_deployment_target=\"13.0\""
)

cd "$SOURCE_DIR"

for platform_config in "${PLATFORMS[@]}"; do
  platform="${platform_config%%:*}"
  config="${platform_config#*:}"

  start_group "Building $platform"
  gn gen "$OUT_DIR/$platform" \
    --args="$COMMON_ARGS $config" \
    --ide=xcode
  ninja -C "$OUT_DIR/$platform" ios_framework_bundle \
    -j "$PARALLEL_BUILDS" \
    --quiet
  end_group
done

start_group "Creating iOS-only XCFramework"

XCFRAMEWORK_ARGS=(-create-xcframework)

for platform in iOS-arm64-device iOS-arm64-simulator; do
  XCFRAMEWORK_ARGS+=(
    -framework "$OUT_DIR/$platform/$FRAMEWORK_NAME.framework"
  )

  if [[ "$DEBUG" == "true" ]] && \
    [[ -d "$OUT_DIR/$platform/$FRAMEWORK_NAME.dSYM" ]]; then
    XCFRAMEWORK_ARGS+=(
      -debug-symbols "$OUT_DIR/$platform/$FRAMEWORK_NAME.dSYM"
    )
  fi
done

XCFRAMEWORK_PATH="$OUT_DIR/$FRAMEWORK_NAME.xcframework"
ZIP_PATH="$OUT_DIR/$FRAMEWORK_NAME.xcframework.zip"

if [[ -e "$XCFRAMEWORK_PATH" ]]; then
  rm -rf -- "$XCFRAMEWORK_PATH"
fi
rm -f -- "$ZIP_PATH"

xcodebuild "${XCFRAMEWORK_ARGS[@]}" -output "$XCFRAMEWORK_PATH"
cp "$SOURCE_DIR/LICENSE" "$XCFRAMEWORK_PATH/"

cd "$OUT_DIR"
zip -9 -r "$ZIP_PATH" "$FRAMEWORK_NAME.xcframework"

end_group

if [[ "${CI:-}" == "true" && -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "framework_name=$FRAMEWORK_NAME" >> "$GITHUB_OUTPUT"
fi

echo "Created $ZIP_PATH"
