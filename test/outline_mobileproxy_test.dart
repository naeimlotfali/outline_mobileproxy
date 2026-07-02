import 'package:flutter_test/flutter_test.dart';
import 'package:outline_mobileproxy/outline_mobileproxy.dart';
import 'package:outline_mobileproxy/outline_mobileproxy_platform_interface.dart';
import 'package:outline_mobileproxy/outline_mobileproxy_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOutlineMobileproxyPlatform
    with MockPlatformInterfaceMixin
    implements OutlineMobileproxyPlatform {
  ProxyInfo? runningProxy;
  String? lastTransportConfig;
  SmartDialerConfig? lastSmartConfig;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<ProxyInfo> start({
    required String transportConfig,
    String localAddress = '127.0.0.1:0',
  }) async {
    lastTransportConfig = transportConfig;
    const info = ProxyInfo(host: '127.0.0.1', port: 12345);
    runningProxy = info;
    return info;
  }

  @override
  Future<ProxyInfo> startSmart({
    required SmartDialerConfig config,
    String localAddress = '127.0.0.1:0',
  }) async {
    lastSmartConfig = config;
    const info = ProxyInfo(host: '127.0.0.1', port: 54321);
    runningProxy = info;
    return info;
  }

  @override
  Future<void> stop({int timeoutSeconds = 5}) async {
    runningProxy = null;
  }

  @override
  Future<bool> isRunning() async => runningProxy != null;

  @override
  Future<ProxyInfo?> currentProxy() async => runningProxy;
}

void main() {
  final OutlineMobileproxyPlatform initialPlatform = OutlineMobileproxyPlatform.instance;

  test('$MethodChannelOutlineMobileproxy is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOutlineMobileproxy>());
  });

  group('OutlineMobileproxy', () {
    late MockOutlineMobileproxyPlatform fakePlatform;
    late OutlineMobileproxy outline;

    setUp(() {
      fakePlatform = MockOutlineMobileproxyPlatform();
      OutlineMobileproxyPlatform.instance = fakePlatform;
      outline = OutlineMobileproxy();
    });

    test('getPlatformVersion', () async {
      expect(await outline.getPlatformVersion(), '42');
    });

    test('start forwards the transport config and returns proxy info', () async {
      final info = await outline.start(transportConfig: 'split:3');

      expect(fakePlatform.lastTransportConfig, 'split:3');
      expect(info.address, '127.0.0.1:12345');
      expect(await outline.isRunning(), isTrue);
    });

    test('startSmart forwards the smart dialer config', () async {
      const config = SmartDialerConfig(
        testDomains: ['example.com'],
        strategiesConfig: 'dns:\n  - {system: {}}',
      );

      final info = await outline.startSmart(config: config);

      expect(fakePlatform.lastSmartConfig, same(config));
      expect(info.port, 54321);
    });

    test('stop clears the running proxy', () async {
      await outline.start(transportConfig: 'split:3');
      await outline.stop();

      expect(await outline.isRunning(), isFalse);
      expect(await outline.currentProxy(), isNull);
    });
  });

  group('ProxyInfo.fromAddress', () {
    test('parses host and port', () {
      final info = ProxyInfo.fromAddress('127.0.0.1:8080');
      expect(info.host, '127.0.0.1');
      expect(info.port, 8080);
    });

    test('throws on malformed address', () {
      expect(() => ProxyInfo.fromAddress('not-an-address'), throwsFormatException);
    });
  });
}
