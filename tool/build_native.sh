#!/usr/bin/env bash
#
# Rebuilds the native Mobileproxy libraries from the Outline SDK Go source
# (golang.getoutline.org/sdk/x/mobileproxy) and installs them into this
# plugin's android/ and ios/ directories.
#
# The exact source revision is pinned in tool/OUTLINE_SDK_REF (a tag or a
# full commit SHA), so a rebuild is reproducible: everyone who runs this
# script against the same ref builds from the same source. To pick up an
# SDK update, bump that file and rerun this script; CI (see
# .github/workflows/build-native.yml) independently rebuilds from the same
# pinned ref on every change to verify the checked-in artifacts still match.
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
OUTLINE_SDK_REF="$(tr -d '[:space:]' < "$PLUGIN_ROOT/tool/OUTLINE_SDK_REF")"

: "${ANDROID_HOME:=$HOME/Library/Android/sdk}"
: "${ANDROID_NDK_HOME:=$(ls -d "$ANDROID_HOME"/ndk/*/ 2>/dev/null | sort -V | tail -1)}"
IOS_MIN_VERSION="13.0"
ANDROID_MIN_API="21"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "==> Fetching outline-sdk @ $OUTLINE_SDK_REF into $WORK_DIR"
git init -q "$WORK_DIR/outline-sdk"
cd "$WORK_DIR/outline-sdk"
git remote add origin "$OUTLINE_SDK_REPO"
# A plain `git fetch --depth 1 origin <ref>` works for both tags and full
# commit SHAs against GitHub, without needing the full repo history.
git fetch --quiet --depth 1 origin "$OUTLINE_SDK_REF"
git checkout --quiet FETCH_HEAD
RESOLVED_SHA="$(git rev-parse FETCH_HEAD)"
echo "==> Resolved to commit $RESOLVED_SHA"

cd "$WORK_DIR/outline-sdk/x"
mkdir -p out

echo "==> Building gomobile/gobind tools pinned to this module's go.sum"
go build -o "$(pwd)/out/" golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind
export PATH="$(pwd)/out:$PATH"
GOMOBILE_VERSION="$(cd "$WORK_DIR/outline-sdk/x" && go list -m -f '{{.Version}}' golang.org/x/mobile)"
GO_VERSION="$(go version | awk '{print $3}')"

# Note: deliberately not running `gomobile init` here. It isn't part of the
# upstream mobileproxy build instructions, and modern gomobile's init step
# tries to `go install golang.org/x/mobile/cmd/gobind@latest`, which can
# require a newer Go than the SDK's own pinned toolchain. The gobind built
# above (pinned via go.sum, already first on PATH) is all `gomobile bind`
# needs.

build_android() {
  echo "==> Building Android AAR (androidapi=$ANDROID_MIN_API)"
  export ANDROID_HOME
  export ANDROID_NDK_HOME
  gomobile bind -ldflags='-s -w' -trimpath -target=android -androidapi="$ANDROID_MIN_API" \
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
  gomobile bind -ldflags='-s -w' -trimpath -target=ios -iosversion="$IOS_MIN_VERSION" \
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

cat > "$PLUGIN_ROOT/NATIVE_PROVENANCE.md" <<EOF
# Native binary provenance

The Android and iOS artifacts under \`android/libs\`, \`android/src/main/jniLibs\`,
and \`ios/Frameworks/Mobileproxy.xcframework\` were built by
[\`tool/build_native.sh\`](tool/build_native.sh) from:

- **Source**: https://github.com/OutlineFoundation/outline-sdk
- **Pinned ref** (\`tool/OUTLINE_SDK_REF\`): \`$OUTLINE_SDK_REF\`
- **Resolved commit**: [\`$RESOLVED_SHA\`](https://github.com/OutlineFoundation/outline-sdk/commit/$RESOLVED_SHA)
- **Package built**: \`golang.getoutline.org/sdk/x/mobileproxy\` (no patches applied)
- **Go**: \`$GO_VERSION\`
- **golang.org/x/mobile**: \`$GOMOBILE_VERSION\`
- **Flags**: \`-ldflags='-s -w' -trimpath\`, \`-androidapi=$ANDROID_MIN_API\`, \`-iosversion=$IOS_MIN_VERSION\`
- **Rebuilt on**: $(date -u +"%Y-%m-%d %H:%M UTC")

[.github/workflows/build-native.yml](.github/workflows/build-native.yml)
independently rebuilds from this same pinned ref on every change to it, so
the result can be verified in the open rather than taken on faith:

- the generated iOS Objective-C header is deterministic given the same
  source and is diffed byte-for-byte;
- the Android Java API surface is compared with \`javap\` (public method
  signatures), not a raw jar diff — the jar's bytes depend on the JDK that
  compiled it, not just the pinned Go source, so two honest builds on
  different JDKs produce different bytes for the same API;
- the compiled native \`.so\`/Mach-O binaries are, likewise, not
  byte-for-bit reproducible across separate toolchain runs (Go embeds a
  build ID even with \`-trimpath\`), so those are verified functionally, by
  building and running the plugin's own example app against them, rather
  than by raw binary diff.
EOF
echo "==> Wrote NATIVE_PROVENANCE.md"

echo "==> Done."
