/// A Flutter plugin exposing the [Outline Mobileproxy SDK]
/// (https://github.com/OutlineFoundation/outline-sdk/tree/main/x/mobileproxy)
/// for Android and iOS.
///
/// The plugin runs a local HTTP CONNECT proxy backed by a Go Mobile dialer,
/// which can forward traffic through a Shadowsocks server, a chain of
/// transports (see the [transport config format]
/// (https://pkg.go.dev/golang.getoutline.org/sdk/x/configurl#hdr-Config_Format)),
/// or an automatically-selected "Smart Dialer" strategy. Point your app's
/// networking library (e.g. `HttpClient.findProxy`, Dio, OkHttp, `WKWebView`)
/// at the returned local address to route its traffic through the proxy.
library outline_mobileproxy;

import 'outline_mobileproxy_platform_interface.dart';

export 'src/outline_mobileproxy_models.dart';

/// Entry point for starting and stopping a local Mobileproxy instance.
///
/// This class is stateless on the Dart side; the actual proxy lifecycle is
/// owned by the native plugin, so a single running proxy is shared by every
/// [OutlineMobileproxy] instance in the isolate.
class OutlineMobileproxy {
  /// Returns the platform name and version, e.g. `Android 14` or `iOS 17.5`.
  Future<String?> getPlatformVersion() {
    return OutlineMobileproxyPlatform.instance.getPlatformVersion();
  }

  /// Starts a local proxy that forwards connections using [transportConfig].
  ///
  /// The config string follows the Outline SDK's [config format]
  /// (https://pkg.go.dev/golang.getoutline.org/sdk/x/configurl#hdr-Config_Format),
  /// for example:
  ///  * `ss://<base64-userinfo>@host:port` for a Shadowsocks server.
  ///  * `split:3` to split outgoing TCP streams at byte 3 (a simple
  ///    censorship-circumvention strategy).
  ///  * `socks5://user:pass@host:port` for a SOCKS5 upstream.
  ///  * Transports can be chained, e.g. `split:3|ss://...`.
  ///
  /// [localAddress] is the address the local proxy binds to. The default,
  /// `127.0.0.1:0`, lets the OS pick a free loopback port; read the returned
  /// [ProxyInfo] to find out which one was chosen.
  ///
  /// If a proxy is already running, it is stopped before the new one starts.
  ///
  /// Throws an [InvalidConfigException] if [transportConfig] cannot be
  /// parsed, or a [ProxyStartException] if the local proxy fails to bind or
  /// start.
  Future<ProxyInfo> start({
    required String transportConfig,
    String localAddress = '127.0.0.1:0',
  }) {
    return OutlineMobileproxyPlatform.instance.start(
      transportConfig: transportConfig,
      localAddress: localAddress,
    );
  }

  /// Starts a local proxy backed by the Outline "Smart Dialer".
  ///
  /// The Smart Dialer probes the DNS/TLS strategies described in
  /// [SmartDialerConfig.strategiesConfig] against
  /// [SmartDialerConfig.testDomains] and automatically selects the first one
  /// that works, which is useful for circumventing network interference
  /// without a proxy server. See the [example strategy config]
  /// (https://github.com/OutlineFoundation/outline-sdk/blob/main/x/examples/smart-proxy/config.yaml).
  ///
  /// If a proxy is already running, it is stopped before the new one starts.
  ///
  /// Throws an [InvalidConfigException] if no working strategy is found, or a
  /// [ProxyStartException] if the local proxy fails to bind or start.
  Future<ProxyInfo> startSmart({
    required SmartDialerConfig config,
    String localAddress = '127.0.0.1:0',
  }) {
    return OutlineMobileproxyPlatform.instance.startSmart(
      config: config,
      localAddress: localAddress,
    );
  }

  /// Stops the currently running local proxy, if any. A no-op if no proxy is
  /// running.
  ///
  /// Waits up to [timeoutSeconds] for in-flight connections to close
  /// gracefully before forcefully closing them.
  ///
  /// Throws a [ProxyStopException] if the proxy could not be stopped
  /// cleanly.
  Future<void> stop({int timeoutSeconds = 5}) {
    return OutlineMobileproxyPlatform.instance.stop(
      timeoutSeconds: timeoutSeconds,
    );
  }

  /// Whether a local proxy is currently running.
  Future<bool> isRunning() {
    return OutlineMobileproxyPlatform.instance.isRunning();
  }

  /// Returns the [ProxyInfo] of the currently running proxy, or `null` if
  /// none is running.
  Future<ProxyInfo?> currentProxy() {
    return OutlineMobileproxyPlatform.instance.currentProxy();
  }
}
