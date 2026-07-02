#!/usr/bin/env bash
#
# Rebuilds the native Mobileproxy libraries from the Outline SDK Go source
# (golang.getoutline.org/sdk/x/mobileproxy) and installs them into this
# plugin's android/ and ios/ directories.
#
# Requirements:
#   - Go 1.24+ (https://go.dev/dl/, or let `go` auto-download the toolchain
#     pinned by outline-sdk/x/go.mod)
#   - Xcode command line tools (for the iOS build)
#   - Android SDK + NDK (set ANDROID_HOME / ANDROID_NDK_HOME below, or via env)
#
# Usage:
#   tool/build_native.sh [android|ios|all]
#
# Rebuilding is only needed if you want to update the vendored SDK version or
# add build tags (e.g. `-tags=psiphon`, see the mobileproxy README). Most
# users can just use the AAR/xcframework already checked into this repo.

set -euo pipefail

TARGET="${1:-all}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
OUTLINE_SDK_REPO="https://github.com/OutlineFoundation/outline-sdk.git"

: "${ANDROID_HOME:=$HOME/Library/Android/sdk}"
: "${ANDROID_NDK_HOME:=$(ls -d "$ANDROID_HOME"/ndk/*/ 2>/dev/null | sort -V | tail -1)}"
IOS_MIN_VERSION="13.0"
ANDROID_MIN_API="21"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "==> Cloning outline-sdk into $WORK_DIR"
git clone --depth 1 "$OUTLINE_SDK_REPO" "$WORK_DIR/outline-sdk"

cd "$WORK_DIR/outline-sdk/x"
mkdir -p out

echo "==> Building gomobile/gobind tools pinned to this module's go.sum"
go build -o "$(pwd)/out/" golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind

export PATH="$(pwd)/out:$PATH"
gomobile init

build_android() {
  echo "==> Building Android AAR (androidapi=$ANDROID_MIN_API)"
  export ANDROID_HOME
  export ANDROID_NDK_HOME
  gomobile bind -ldflags='-s -w' -target=android -androidapi="$ANDROID_MIN_API" \
    -o "$(pwd)/out/mobileproxy.aar" golang.getoutline.org/sdk/x/mobileproxy

  echo "==> Unpacking AAR (AGP disallows local .aar deps in a library module)"
  local unpack_dir="$(pwd)/out/aar_unpacked"
  rm -rf "$unpack_dir" && mkdir -p "$unpack_dir"
  unzip -q "$(pwd)/out/mobileproxy.aar" -d "$unpack_dir"

  mkdir -p "$PLUGIN_ROOT/android/libs"
  cp "$unpack_dir/classes.jar" "$PLUGIN_ROOT/android/libs/mobileproxy-classes.jar"
  cp "$unpack_dir/proguard.txt" "$PLUGIN_ROOT/android/mobileproxy-consumer-rules.pro"
  for abi_dir in "$unpack_dir"/jni/*/; do
    abi="$(basename "$abi_dir")"
    mkdir -p "$PLUGIN_ROOT/android/src/main/jniLibs/$abi"
    cp "$abi_dir/libgojni.so" "$PLUGIN_ROOT/android/src/main/jniLibs/$abi/libgojni.so"
  done
  echo "==> Android artifacts installed under android/libs and android/src/main/jniLibs"
}

build_ios() {
  echo "==> Building iOS XCFramework (iosversion=$IOS_MIN_VERSION)"
  gomobile bind -ldflags='-s -w' -target=ios -iosversion="$IOS_MIN_VERSION" \
    -o "$(pwd)/out/Mobileproxy.xcframework" golang.getoutline.org/sdk/x/mobileproxy

  mkdir -p "$PLUGIN_ROOT/ios/Frameworks"
  rm -rf "$PLUGIN_ROOT/ios/Frameworks/Mobileproxy.xcframework"
  cp -R "$(pwd)/out/Mobileproxy.xcframework" "$PLUGIN_ROOT/ios/Frameworks/Mobileproxy.xcframework"
  echo "==> iOS artifact installed under ios/Frameworks/Mobileproxy.xcframework"
}

case "$TARGET" in
  android) build_android ;;
  ios) build_ios ;;
  all) build_android; build_ios ;;
  *) echo "Unknown target: $TARGET (expected android, ios, or all)" >&2; exit 1 ;;
esac

echo "==> Done."
