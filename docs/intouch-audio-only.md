# Intouch audio-only Apple WebRTC

This branch adds an `apple_audio_only` target for Intouch's voice-only Expo app.
It is pinned to the WebRTC source commit recorded in `build/VERSION` for
`144.7559.10`, the exact `WebRTC-SDK` version required by
`@livekit/react-native-webrtc@144.1.2`.

The source patch removes the Objective-C camera capturer, camera preview, and
their public framework headers while preserving peer connections, WebRTC audio,
audio codecs, data channels, and remote video types. The build ends with a
binary string audit of every iOS XCFramework slice and fails if known camera
classes or APIs remain.

The custom XCFramework contains only the two slices Intouch needs:

- arm64 iOS devices for development, Ad Hoc, TestFlight, and App Store builds;
- arm64 iOS Simulator for development on Apple Silicon Macs.

It deliberately omits Intel simulator, macOS, Mac Catalyst, tvOS, and visionOS.

GitHub Actions is intentionally disabled on this fork. Nothing in this branch
has been compiled or published. On a suitable macOS host, the manual build is:

```sh
cd build
./build.apple_audio_only.sh f47af7bc965851090bef9fce9a4284f468d20a44 release
```

Do not replace the app's current `WebRTC-SDK` dependency until the resulting
XCFramework has passed both the included audit and an App Store Connect upload.

The XCFramework is only half of the integration. The app must also patch
`@livekit/react-native-webrtc` so its iOS bridge does not import
`RTCCameraVideoCapturer`, compile `VideoCaptureController`, enumerate video
devices, or map a permission request to `AVMediaTypeVideo`. That wrapper patch
must continue to reject `getUserMedia({ video: true })` while allowing
`getUserMedia({ audio: true, video: false })`.
