/// Information about a running local proxy started by [OutlineMobileproxy].
class ProxyInfo {
  /// Creates a [ProxyInfo].
  const ProxyInfo({required this.host, required this.port});

  /// Creates a [ProxyInfo] from the `host:port` address string returned by
  /// the native SDK.
  factory ProxyInfo.fromAddress(String address) {
    final separatorIndex = address.lastIndexOf(':');
    if (separatorIndex <= 0 || separatorIndex == address.length - 1) {
      throw FormatException('Invalid proxy address: $address');
    }
    final host = address.substring(0, separatorIndex);
    final port = int.parse(address.substring(separatorIndex + 1));
    return ProxyInfo(host: host, port: port);
  }

  /// The IP address the local proxy is bound to (e.g. `127.0.0.1`).
  final String host;

  /// The port the local proxy is bound to.
  final int port;

  /// The `host:port` address of the local proxy, suitable for use with
  /// `HttpClient.findProxy` and similar APIs.
  String get address => '$host:$port';

  @override
  String toString() => 'ProxyInfo($address)';

  @override
  bool operator ==(Object other) =>
      other is ProxyInfo && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// Options controlling how the Smart Dialer probes candidate strategies.
///
/// The Smart Dialer automatically selects a working DNS/TLS strategy by
/// testing connectivity against [testDomains], using the candidate
/// strategies described by [strategiesConfig] (YAML). See
/// https://github.com/OutlineFoundation/outline-sdk/blob/main/x/examples/smart-proxy/config.yaml
/// for the configuration format.
class SmartDialerConfig {
  /// Creates a [SmartDialerConfig].
  const SmartDialerConfig({
    required this.testDomains,
    required this.strategiesConfig,
    this.enableLogging = false,
  });

  /// Domains used to test connectivity for each candidate strategy.
  final List<String> testDomains;

  /// The YAML document describing the DNS/TLS strategies to try.
  final String strategiesConfig;

  /// When true, the native SDK writes strategy-selection diagnostics to the
  /// platform log (Logcat / Xcode console).
  final bool enableLogging;
}

/// Base class for exceptions thrown by [OutlineMobileproxy].
sealed class OutlineMobileproxyException implements Exception {
  const OutlineMobileproxyException(this.message);

  /// A human-readable description of the failure.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the supplied transport configuration, or the Smart Dialer
/// strategy configuration, could not be parsed or resolved into a working
/// dialer.
final class InvalidConfigException extends OutlineMobileproxyException {
  const InvalidConfigException(super.message);
}

/// Thrown when the local proxy could not be started, for example because the
/// requested local address/port is already in use.
final class ProxyStartException extends OutlineMobileproxyException {
  const ProxyStartException(super.message);
}

/// Thrown when the local proxy could not be stopped cleanly.
final class ProxyStopException extends OutlineMobileproxyException {
  const ProxyStopException(super.message);
}

/// Thrown when an operation is requested that requires a running proxy (or
/// requires no proxy to be running) and that precondition isn't met.
final class ProxyStateException extends OutlineMobileproxyException {
  const ProxyStateException(super.message);
}

/// Thrown for any other native-side failure that doesn't map to a more
/// specific exception type.
final class OutlineMobileproxyPlatformException
    extends OutlineMobileproxyException {
  const OutlineMobileproxyPlatformException(super.message);
}
