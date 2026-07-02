import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outline_mobileproxy/outline_mobileproxy_method_channel.dart';
import 'package:outline_mobileproxy/outline_mobileproxy_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelOutlineMobileproxy();
  const channel = MethodChannel('outline_mobileproxy');

  final calls = <MethodCall>[];
  Object? Function(MethodCall call) handler = (_) => null;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        calls.add(methodCall);
        return handler(methodCall);
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    handler = (_) => '42';
    expect(await platform.getPlatformVersion(), '42');
  });

  test('start sends transportConfig and localAddress, parses the returned address', () async {
    handler = (_) => '127.0.0.1:12345';

    final info = await platform.start(transportConfig: 'split:3', localAddress: '127.0.0.1:0');

    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {
      'transportConfig': 'split:3',
      'localAddress': '127.0.0.1:0',
    });
    expect(info.address, '127.0.0.1:12345');
  });

  test('startSmart sends test domains and strategies config', () async {
    handler = (_) => '127.0.0.1:9999';

    final info = await platform.startSmart(
      config: const SmartDialerConfig(
        testDomains: ['a.com', 'b.com'],
        strategiesConfig: 'dns:\n  - {system: {}}',
        enableLogging: true,
      ),
    );

    expect(calls.single.method, 'startSmart');
    expect(calls.single.arguments, {
      'testDomains': ['a.com', 'b.com'],
      'strategiesConfig': 'dns:\n  - {system: {}}',
      'enableLogging': true,
      'localAddress': '127.0.0.1:0',
    });
    expect(info.port, 9999);
  });

  test('stop sends the timeout', () async {
    handler = (_) => null;
    await platform.stop(timeoutSeconds: 3);

    expect(calls.single.method, 'stop');
    expect(calls.single.arguments, {'timeoutSeconds': 3});
  });

  test('isRunning defaults to false when the platform returns null', () async {
    handler = (_) => null;
    expect(await platform.isRunning(), isFalse);
  });

  test('currentProxy returns null when no proxy is running', () async {
    handler = (_) => null;
    expect(await platform.currentProxy(), isNull);
  });

  test('maps PlatformException codes to typed exceptions', () async {
    handler = (_) => throw PlatformException(code: 'INVALID_CONFIG', message: 'bad config');
    expect(
      () => platform.start(transportConfig: 'nonsense'),
      throwsA(isA<InvalidConfigException>()),
    );

    handler = (_) => throw PlatformException(code: 'START_FAILED', message: 'boom');
    expect(
      () => platform.start(transportConfig: 'split:3'),
      throwsA(isA<ProxyStartException>()),
    );

    handler = (_) => throw PlatformException(code: 'STOP_FAILED', message: 'boom');
    expect(() => platform.stop(), throwsA(isA<ProxyStopException>()));

    handler = (_) => throw PlatformException(code: 'SOMETHING_ELSE', message: 'boom');
    expect(
      () => platform.start(transportConfig: 'split:3'),
      throwsA(isA<OutlineMobileproxyPlatformException>()),
    );
  });
}
