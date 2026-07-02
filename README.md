# outline_mobileproxy

[![pub package](https://img.shields.io/pub/v/outline_mobileproxy.svg)](https://pub.dev/packages/outline_mobileproxy)
[![Build native binaries](https://github.com/naeimlotfali/outline_mobileproxy/actions/workflows/build-native.yml/badge.svg)](https://github.com/naeimlotfali/outline_mobileproxy/actions/workflows/build-native.yml)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> **Not affiliated with or endorsed by the Outline Foundation.** This is an
> independent, third-party wrapper around their open-source SDK.

A Flutter plugin for the Outline SDK's [Mobileproxy](https://github.com/OutlineFoundation/outline-sdk/tree/main/x/mobileproxy)
library, for Android and iOS.

Mobileproxy runs a local HTTP CONNECT proxy on-device, backed by a Go
[`StreamDialer`](https://pkg.go.dev/golang.getoutline.org/sdk/transport#StreamDialer)
that can tunnel through a Shadowsocks server, a SOCKS5 upstream, a chain of
transports, or an automatically-selected "Smart Dialer" strategy for
circumventing network interference. Point your app's HTTP client, gRPC
channel, or WebView at the local proxy address this plugin returns, and its
traffic is routed accordingly — **no VPN permissions, no `NEPacketTunnelProvider`,
no `VpnService`, required.**

This package does *not* implement its own proxy protocol logic; it's a thin,
idiomatic Flutter wrapper around the official
[`golang.getoutline.org/sdk/x/mobileproxy`](https://pkg.go.dev/golang.getoutline.org/sdk/x/mobileproxy)
Go Mobile bindings, compiled to a real Android AAR and iOS XCFramework (see
[How the native binaries are built](#how-the-native-binaries-are-built)).

## Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Static transport configuration](#static-transport-configuration)
  - [Smart Dialer](#smart-dialer-automatic-strategy-selection)
  - [Routing your networking library through the proxy](#routing-your-networking-library-through-the-proxy)
  - [Error handling](#error-handling)
- [API reference](#api-reference)
- [Example app](#example-app)
- [How the native binaries are built](#how-the-native-binaries-are-built)
- [FAQ](#faq)
- [License](#license)

## Features

- Local HTTP CONNECT proxy, no VPN entitlement or system-level tunnel needed.
- Static transport configuration (`ss://`, `socks5://`, `split:`, chained transports, ...).
- Smart Dialer support: auto-select a working DNS/TLS strategy from a YAML
  strategy list, tested against domains you provide.
- Typed Dart API with specific exceptions (`InvalidConfigException`,
  `ProxyStartException`, `ProxyStopException`).
- Prebuilt native binaries checked in — no Go toolchain needed to consume
  the plugin, only to rebuild it.

## Installation

```yaml
dependencies:
  outline_mobileproxy: ^0.0.1
```

```bash
flutter pub get
```

### Platform requirements

| Platform | Minimum version |
|----------|------------------|
| Android  | API 21 (Android 5.0) |
| iOS      | 13.0 |

No further native setup is required — the plugin bundles the compiled
Mobileproxy library for both platforms.

## Usage

### Static transport configuration

```dart
import 'package:outline_mobileproxy/outline_mobileproxy.dart';

final outline = OutlineMobileproxy();

final proxy = await outline.start(
  transportConfig: 'ss://<base64-userinfo>@host:port',
);
print('Local proxy listening at ${proxy.address}'); // e.g. 127.0.0.1:54321

// ... configure your networking library, see below ...

await outline.stop();
```

The `transportConfig` string follows the Outline SDK's
[config format](https://pkg.go.dev/golang.getoutline.org/sdk/x/configurl#hdr-Config_Format),
for example:

- `ss://<base64-userinfo>@host:port` — a Shadowsocks server (the standard
  Outline access key format).
- `socks5://user:pass@host:port` — a SOCKS5 upstream.
- `split:3` — split outgoing TCP streams at byte 3, a simple
  censorship-circumvention strategy that needs no server.
- `split:3|ss://...` — transports can be chained.

### Smart Dialer (automatic strategy selection)

The Smart Dialer probes a list of DNS/TLS strategies against domains you
provide, and picks the first one that works — useful when you don't have (or
don't want to run) a proxy server, and just need to get past DNS/SNI-based
interference.

```dart
final proxy = await outline.startSmart(
  config: SmartDialerConfig(
    testDomains: ['www.google.com', 'i.ytimg.com'],
    strategiesConfig: strategiesYaml, // see example config below
  ),
);
```

An example strategy config can be found at
[`x/examples/smart-proxy/config.yaml`](https://github.com/OutlineFoundation/outline-sdk/blob/main/x/examples/smart-proxy/config.yaml)
in the outline-sdk repository.

### Routing your networking library through the proxy

Once started, `proxy.address` is a plain `host:port` HTTP proxy you can wire
into whatever networking stack your app already uses.

**`dart:io` `HttpClient`:**

```dart
import 'dart:io';

final httpClient = HttpClient();
httpClient.findProxy = (uri) => 'PROXY ${proxy.address}';
final response = await httpClient.getUrl(Uri.parse('https://example.com'));
```

**Dio:**

```dart
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

final dio = Dio();
(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.findProxy = (uri) => 'PROXY ${proxy.address}';
  return client;
};
```

**gRPC (`package:grpc` v3.2.4+):**

```dart
final channel = ClientChannel(
  'grpc.example.com',
  port: 443,
  options: ChannelOptions(
    proxy: Proxy(host: proxy.host, port: proxy.port),
  ),
);
```

**Android WebView (`androidx.webkit`, native code):**

```kotlin
ProxyController.getInstance().setProxyOverride(
  ProxyConfig.Builder().addProxyRule(proxy.address()).build(),
  {},
  {},
)
```

**iOS `WKWebView` (iOS 17+, native code):**

```swift
let endpoint = NWEndpoint.hostPort(
  host: NWEndpoint.Host(proxyHost),
  port: NWEndpoint.Port(integerLiteral: UInt16(proxyPort))
)
let configuration = WKWebViewConfiguration()
configuration.websiteDataStore.proxyConfigurations = [
  .init(httpCONNECTProxy: endpoint)
]
```

More platform-specific snippets (OkHttp, JVM system properties) are in the
[Mobileproxy README](https://github.com/OutlineFoundation/outline-sdk/tree/main/x/mobileproxy#configure-your-http-client-or-networking-library).

### Error handling

```dart
try {
  await outline.start(transportConfig: key);
} on InvalidConfigException catch (e) {
  // The transport config (or Smart Dialer strategy config) is invalid, or no
  // working strategy was found.
} on ProxyStartException catch (e) {
  // The local proxy failed to bind/start (e.g. address already in use).
} on ProxyStopException catch (e) {
  // The proxy failed to stop cleanly.
}
```

Calling `start`/`startSmart` while a proxy is already running stops the
previous one first. `stop()` is a no-op if nothing is running. Always call
`stop()` when your app is done with the proxy (e.g. `dispose()`,
`AppLifecycleState.detached`) to release the bound port.

## API reference

| Method | Description |
|--------|--------------|
| `start({transportConfig, localAddress})` | Starts a proxy using a static transport config. Returns a `ProxyInfo`. |
| `startSmart({config, localAddress})` | Starts a proxy using the Smart Dialer. Returns a `ProxyInfo`. |
| `stop({timeoutSeconds})` | Stops the running proxy, if any. |
| `isRunning()` | Whether a proxy is currently running. |
| `currentProxy()` | The `ProxyInfo` of the running proxy, or `null`. |
| `getPlatformVersion()` | The host OS name/version, mostly useful for diagnostics. |

`localAddress` defaults to `127.0.0.1:0`, letting the OS pick a free loopback
port — read `ProxyInfo.port` to find out which one.

## Example app

The [`example/`](example) app demonstrates both modes: enter a transport
config, start/stop the proxy, and fire a test HTTP request through it. Run it
with:

```bash
cd example
flutter run
```

The plugin's own [integration tests](example/integration_test/plugin_integration_test.dart)
exercise the real native proxy (start/stop/error-mapping) end-to-end on a
device or simulator:

```bash
cd example
flutter test integration_test/plugin_integration_test.dart -d <device-id>
```

## How the native binaries are built

This plugin bundles prebuilt Mobileproxy binaries:

- `android/libs/mobileproxy-classes.jar` + `android/src/main/jniLibs/*/libgojni.so`
- `ios/Frameworks/Mobileproxy.xcframework`

They're built from the upstream Go source
(`golang.getoutline.org/sdk/x/mobileproxy`) with
[Go Mobile](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile), at a
**pinned, tagged revision** rather than a moving branch — see
[`tool/OUTLINE_SDK_REF`](tool/OUTLINE_SDK_REF) for the exact ref and
[`NATIVE_PROVENANCE.md`](NATIVE_PROVENANCE.md) for the resolved commit,
toolchain versions, and flags used to produce what's currently checked in.
The Android artifacts are the AAR produced by `gomobile bind`, unpacked into
a plain jar + `jniLibs`, because the Android Gradle Plugin does not allow a
library module to declare a local `.aar` file dependency (it can't be
re-packaged into this plugin's own AAR).

**Verifying the binaries.** [`.github/workflows/build-native.yml`](.github/workflows/build-native.yml)
rebuilds both artifacts from that same pinned ref on every push/PR that
touches it, in the open, and:

- diffs the managed Java layer (`mobileproxy-classes.jar`) and the generated
  iOS Objective-C header byte-for-byte against what's checked in — these are
  deterministic given the same source and toolchain, so any mismatch fails
  the build;
- builds and links the example app against the freshly built native
  libraries, and runs the plugin's [integration tests](example/integration_test/plugin_integration_test.dart)
  against them on a real Android emulator and iOS Simulator, to functionally
  verify the compiled `.so`/Mach-O binaries (these embed a Go build ID even
  with `-trimpath`, so they aren't expected to be byte-identical across
  separate builds — functional verification is the honest bar here, not a
  raw binary diff);
- uploads the freshly built artifacts so anyone can download and compare
  them independently, rather than trusting the checked-in copies by
  inspection alone.

To rebuild locally, e.g. to bump [`tool/OUTLINE_SDK_REF`](tool/OUTLINE_SDK_REF)
for an SDK update:

```bash
tool/build_native.sh all
```

> Psiphon fallback support is intentionally **not** built in by default: the
> Psiphon library is GPL-licensed, and using it requires a config obtained
> directly from the Psiphon team (`sponsor@psiphon.ca`). If you need it,
> build a `-tags=psiphon` variant yourself following the
> [Mobileproxy README](https://github.com/OutlineFoundation/outline-sdk/tree/main/x/mobileproxy#readme)
> and be mindful of the licensing implications for your app.

## FAQ

**Does this need VPN permissions?**
No. Mobileproxy runs a local HTTP proxy, not a VPN. Nothing is added to
`AndroidManifest.xml` or app entitlements; you explicitly opt individual
networking clients into using the proxy.

**Can I use my existing Outline / Shadowsocks access key?**
Yes — pass it directly as `transportConfig`, e.g.
`outline.start(transportConfig: 'ss://<key>@host:port')`.

**Does it tunnel *all* app traffic automatically?**
No, only whatever you explicitly point at `proxy.address` (see
[Routing your networking library through the proxy](#routing-your-networking-library-through-the-proxy)).
For system-wide tunneling you'd need a VPN service instead, which is out of
scope for this package.

**Why doesn't `start()` throw if I call it twice?**
By design — calling `start`/`startSmart` again stops the previous proxy and
starts a new one, which matches the common "switch server" UX. If you need
stricter semantics, check `isRunning()` first.

## License

Apache License 2.0 — see [LICENSE](LICENSE). This plugin wraps the
[Outline SDK](https://github.com/OutlineFoundation/outline-sdk), also
Apache-2.0 licensed, by the Outline Foundation / Jigsaw. Not officially
affiliated with or endorsed by the Outline Foundation.
