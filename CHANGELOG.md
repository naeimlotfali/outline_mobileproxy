## 0.0.2

* Pin the vendored outline-sdk source to a tagged revision
  (`tool/OUTLINE_SDK_REF`, currently `x/v0.2.0`) instead of building from a
  moving branch, and record the resolved commit/toolchain/flags in
  `NATIVE_PROVENANCE.md`.
* Add a CI workflow (`.github/workflows/build-native.yml`) that rebuilds the
  native binaries from that pinned ref on every change, diffs the
  deterministic parts (Java layer, iOS header) against what's checked in,
  and runs the plugin's integration tests against the rebuilt binaries on a
  real Android emulator and iOS Simulator.
* No API or behavior changes; native binaries reflect a fresh, verified
  build from the pinned source.

## 0.0.1

* Initial release.
* Wraps the Outline SDK's [Mobileproxy](https://github.com/OutlineFoundation/outline-sdk/tree/main/x/mobileproxy)
  Go Mobile library for Android and iOS.
* `OutlineMobileproxy.start` — run a local proxy from a static transport
  configuration string (Shadowsocks, SOCKS5, `split:`, chained transports,
  etc).
* `OutlineMobileproxy.startSmart` — run a local proxy backed by the Smart
  Dialer, which automatically probes DNS/TLS strategies against a set of test
  domains.
* `OutlineMobileproxy.stop`, `isRunning`, `currentProxy`.
* Bundles prebuilt native binaries (`android/libs/mobileproxy-classes.jar` +
  `jniLibs`, `ios/Frameworks/Mobileproxy.xcframework`) built from the
  upstream Go source; see `tool/build_native.sh` to rebuild them.
