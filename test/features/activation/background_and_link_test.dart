import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/activation/providers/activation_provider.dart';
import 'package:tron/features/activation/services/background_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only tron://trigger counts as a trigger link', () {
    expect(isTriggerLink(Uri.parse('tron://trigger')), isTrue);
    expect(isTriggerLink(Uri.parse('tron://settings')), isFalse);
    expect(isTriggerLink(Uri.parse('https://trigger')), isFalse);
    expect(isTriggerLink(Uri.parse('tron:trigger')), isFalse);
  });

  group('BackgroundGuard', () {
    const channel = MethodChannel('tron/background');
    final calls = <String>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('start and stop reach the Android service channel', () async {
      const guard = BackgroundGuard();
      expect(await guard.start(), isTrue);
      expect(await guard.stop(), isTrue);
      expect(calls, ['start', 'stop']);
    });

    test('does nothing on platforms without the service', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const guard = BackgroundGuard();
      expect(guard.isSupported, isFalse);
      expect(await guard.start(), isFalse);
      expect(calls, isEmpty);
    });

    test(
      'a refused start from the background is reported, not thrown',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(code: 'start_failed');
            });
        expect(await const BackgroundGuard().start(), isFalse);
      },
    );
  });
}
