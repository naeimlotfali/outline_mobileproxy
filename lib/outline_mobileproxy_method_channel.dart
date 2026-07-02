import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'outline_mobileproxy_platform_interface.dart';

/// An implementation of [OutlineMobileproxyPlatform] that uses method
/// channels to talk to the native Mobileproxy SDK (Go Mobile bindings) on
/// Android and iOS.
class MethodChannelOutlineMobileproxy extends OutlineMobileproxyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('outline_mobileproxy');

  @override
  Future<String?> getPlatformVersion() async {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<ProxyInfo> start({
    required String transportConfig,
    String localAddress = '127.0.0.1:0',
  }) async {
    try {
      final address = await methodChannel.invokeMethod<String>('start', {
        'transportConfig': transportConfig,
        'localAddress': localAddress,
      });
      return ProxyInfo.fromAddress(address!);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<ProxyInfo> startSmart({
    required SmartDialerConfig config,
    String localAddress = '127.0.0.1:0',
  }) async {
    try {
      final address = await methodChannel.invokeMethod<String>('startSmart', {
        'testDomains': config.testDomains,
        'strategiesConfig': config.strategiesConfig,
        'enableLogging': config.enableLogging,
        'localAddress': localAddress,
      });
      return ProxyInfo.fromAddress(address!);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> stop({int timeoutSeconds = 5}) async {
    try {
      await methodChannel.invokeMethod<void>('stop', {
        'timeoutSeconds': timeoutSeconds,
      });
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<bool> isRunning() async {
    final running = await methodChannel.invokeMethod<bool>('isRunning');
    return running ?? false;
  }

  @override
  Future<ProxyInfo?> currentProxy() async {
    final address = await methodChannel.invokeMethod<String?>('currentProxy');
    if (address == null) return null;
    return ProxyInfo.fromAddress(address);
  }

  OutlineMobileproxyException _mapException(PlatformException e) {
    final message = e.message ?? 'Unknown error';
    switch (e.code) {
      case 'INVALID_CONFIG':
        return InvalidConfigException(message);
      case 'START_FAILED':
        return ProxyStartException(message);
      case 'STOP_FAILED':
        return ProxyStopException(message);
      case 'BAD_STATE':
        return ProxyStateException(message);
      default:
        return OutlineMobileproxyPlatformException(message);
    }
  }
}
