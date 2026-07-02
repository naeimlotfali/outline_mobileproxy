// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:outline_mobileproxy/outline_mobileproxy.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final outline = OutlineMobileproxy();

  tearDown(() async {
    await outline.stop();
  });

  testWidgets('getPlatformVersion returns a non-empty string', (tester) async {
    final version = await outline.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  testWidgets('start with a valid transport config runs a real local proxy', (tester) async {
    expect(await outline.isRunning(), isFalse);

    final proxy = await outline.start(transportConfig: 'split:3');

    expect(proxy.host.isNotEmpty, isTrue);
    expect(proxy.port, greaterThan(0));
    expect(await outline.isRunning(), isTrue);
    expect(await outline.currentProxy(), proxy);

    await outline.stop();

    expect(await outline.isRunning(), isFalse);
    expect(await outline.currentProxy(), isNull);
  });

  testWidgets('start with an invalid transport config throws InvalidConfigException', (tester) async {
    expect(
      () => outline.start(transportConfig: 'not a valid config \x00'),
      throwsA(isA<InvalidConfigException>()),
    );
    expect(await outline.isRunning(), isFalse);
  });

  testWidgets('starting a second proxy stops the first one', (tester) async {
    final first = await outline.start(transportConfig: 'split:3', localAddress: '127.0.0.1:0');
    final second = await outline.start(transportConfig: 'split:5', localAddress: '127.0.0.1:0');

    expect(await outline.currentProxy(), second);
    expect(second, isNot(equals(first)));
  });
}
