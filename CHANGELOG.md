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
