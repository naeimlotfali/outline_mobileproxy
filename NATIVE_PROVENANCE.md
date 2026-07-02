# Native binary provenance

The Android and iOS artifacts under `android/libs`, `android/src/main/jniLibs`,
and `ios/Frameworks/Mobileproxy.xcframework` were built by
[`tool/build_native.sh`](tool/build_native.sh) from:

- **Source**: https://github.com/OutlineFoundation/outline-sdk
- **Pinned ref** (`tool/OUTLINE_SDK_REF`): `x/v0.2.0`
- **Resolved commit**: [`3e47cdf51be057283c69807b1ea2091a2d8667d9`](https://github.com/OutlineFoundation/outline-sdk/commit/3e47cdf51be057283c69807b1ea2091a2d8667d9)
- **Package built**: `golang.getoutline.org/sdk/x/mobileproxy` (no patches applied)
- **Go**: `go1.24.8`
- **golang.org/x/mobile**: `v0.0.0-20240520174638-fa72addaaa1b`
- **Flags**: `-ldflags='-s -w' -trimpath`, `-androidapi=21`, `-iosversion=13.0`
- **Rebuilt on**: 2026-07-02 23:39 UTC

[.github/workflows/build-native.yml](.github/workflows/build-native.yml)
independently rebuilds from this same pinned ref on every change to it, so
the result can be verified in the open rather than taken on faith. The
managed Java layer (`mobileproxy-classes.jar`) and the generated
Objective-C header are deterministic and diffed exactly; the compiled
native `.so`/Mach-O binaries are not byte-for-bit reproducible across
separate toolchain runs (Go embeds a build ID even with `-trimpath`), so
those are compared by rebuilding-and-linking against the plugin's own
Kotlin/Swift code instead of a raw binary diff.
