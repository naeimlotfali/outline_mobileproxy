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
- **Rebuilt on**: 2026-07-03 01:10 UTC

[.github/workflows/build-native.yml](.github/workflows/build-native.yml)
independently rebuilds from this same pinned ref on every change to it, so
the result can be verified in the open rather than taken on faith:

- the generated iOS Objective-C header is deterministic given the same
  source and is diffed byte-for-byte;
- the Android Java API surface is compared with `javap` (public method
  signatures), not a raw jar diff — the jar's bytes depend on the JDK that
  compiled it, not just the pinned Go source, so two honest builds on
  different JDKs produce different bytes for the same API;
- the compiled native `.so`/Mach-O binaries are, likewise, not
  byte-for-bit reproducible across separate toolchain runs (Go embeds a
  build ID even with `-trimpath`), so those are verified functionally, by
  building and running the plugin's own example app against them, rather
  than by raw binary diff.
