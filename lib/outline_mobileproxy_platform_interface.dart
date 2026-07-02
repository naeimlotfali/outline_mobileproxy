import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'outline_mobileproxy_method_channel.dart';
import 'src/outline_mobileproxy_models.dart';

export 'src/outline_mobileproxy_models.dart';

/// The interface that implementations of `outline_mobileproxy` must
/// implement.
///
/// Platform implementations should extend this class rather than implement
/// it, as `extends` ensures that the subclass will get the default
/// implementation, while platform implementations that `implements` this
/// interface will be broken by newly added [OutlineMobileproxyPlatform]
/// methods.
abstract class OutlineMobileproxyPlatform extends PlatformInterface {
  /// Constructs a OutlineMobileproxyPlatform.
  OutlineMobileproxyPlatform() : super(token: _token);

  static final Object _token = Object();

  static OutlineMobileproxyPlatform _instance = MethodChannelOutlineMobileproxy();

  /// The default instance of [OutlineMobileproxyPlatform] to use.
  ///
  /// Defaults to [MethodChannelOutlineMobileproxy].
  static OutlineMobileproxyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OutlineMobileproxyPlatform] when
  /// they register themselves.
  static set instance(OutlineMobileproxyPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform name and version, e.g. `Android 14` or `iOS 17.5`.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Starts a local proxy that forwards traffic through the given
  /// [transportConfig].
  ///
  /// See
  /// https://pkg.go.dev/golang.getoutline.org/sdk/x/configurl#hdr-Config_Format
  /// for the configuration string format (e.g. Shadowsocks URLs, `split:`,
  /// `socks5://`, chained transports, etc).
  ///
  /// [localAddress] is the address the local proxy listens on. Use port `0`
  /// (the default) to let the OS pick a free port.
  Future<ProxyInfo> start({
    required String transportConfig,
    String localAddress = '127.0.0.1:0',
  }) {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Starts a local proxy backed by the Smart Dialer, which automatically
  /// selects a working DNS/TLS strategy by probing
  /// [SmartDialerConfig.testDomains].
  Future<ProxyInfo> startSmart({
    required SmartDialerConfig config,
    String localAddress = '127.0.0.1:0',
  }) {
    throw UnimplementedError('startSmart() has not been implemented.');
  }

  /// Stops the currently running local proxy, if any.
  ///
  /// Waits up to [timeoutSeconds] for in-flight connections to close
  /// gracefully before forcefully closing them.
  Future<void> stop({int timeoutSeconds = 5}) {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Whether a local proxy is currently running.
  Future<bool> isRunning() {
    throw UnimplementedError('isRunning() has not been implemented.');
  }

  /// Returns the [ProxyInfo] of the currently running proxy, or `null` if
  /// none is running.
  Future<ProxyInfo?> currentProxy() {
    throw UnimplementedError('currentProxy() has not been implemented.');
  }
}
