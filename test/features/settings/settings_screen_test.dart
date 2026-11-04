import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/features/activation/services/permission_service.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/settings/providers/settings_provider.dart';
import 'package:tron/features/settings/screens/settings_screen.dart';

Future<ProviderContainer> pumpSettings(
  WidgetTester tester, {
  Size size = const Size(390, 2400),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      permissionSnapshotProvider.overrideWith(
        (ref) => Future.value(
          const PermissionSnapshot(
            notifications: true,
            exactAlarm: true,
            batteryUnrestricted: false,
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const SettingsScreen(),
        ),
      ),
    ),
  );
  await container.read(settingsProvider.future);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Choosing a phone style is saved and turns auto-detect off', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    expect(
      (await container.read(settingsProvider.future)).phoneStyle,
      PhoneStyle.auto,
    );
    await tester.tap(find.text('Samsung'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).phoneStyle,
      PhoneStyle.samsung,
    );
  });

  testWidgets('Auto-detect checkbox returns the choice to the device', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('Samsung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tự nhận diện theo máy đang dùng'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).phoneStyle,
      PhoneStyle.auto,
    );
  });

  testWidgets('Vibration switch is saved', (tester) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('Rung khi có cuộc gọi'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).vibrateOnCall,
      isFalse,
    );
  });

  testWidgets('Compact screen with large text does not overflow', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'No back tap option, only flip',
    (tester) async {
      await pumpSettings(tester);
      expect(find.textContaining('Gõ lưng'), findsNothing);
      expect(find.textContaining('gõ lưng'), findsNothing);
      expect(find.textContaining('Back Tap'), findsNothing);
      expect(find.text('Lật úp máy'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('Reply pause shows only while waiting for the user is on', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    expect(find.text('Chờ sau khi bạn nói xong'), findsOneWidget);
    expect(find.text('1 giây'), findsOneWidget);
    await tester.tap(find.text('Chờ tôi nói xong mới nói tiếp'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).waitForReply,
      isFalse,
    );
    expect(find.text('Chờ sau khi bạn nói xong'), findsNothing);
  });

  testWidgets('Dragging the reply pause saves once, on release', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    final slider = find.byType(Slider);
    final box = tester.getRect(slider);
    // Thanh trượt 0,5–5 giây: kéo từ đầu trái tới gần cuối phải.
    final gesture = await tester.startGesture(
      Offset(box.left + 24, box.center.dy),
    );
    await gesture.moveTo(Offset(box.right - 24, box.center.dy));
    await tester.pump();
    // Đang kéo: số trên màn đổi theo tay, chưa lưu gì.
    expect(find.text('1 giây'), findsNothing);
    expect(
      (await container.read(settingsProvider.future)).replyPause,
      AppSettings.defaultReplyPause,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    final saved = (await container.read(settingsProvider.future)).replyPause;
    expect(saved, AppSettings.maxReplyPause);
    expect(find.text('5 giây'), findsOneWidget);
    expect(saved.inMilliseconds % 500, 0);
  });

  test('Reply pause label reads like Vietnamese seconds', () {
    expect(ReplyPauseTile.label(const Duration(milliseconds: 500)), '0,5 giây');
    expect(ReplyPauseTile.label(const Duration(seconds: 1)), '1 giây');
    expect(
      ReplyPauseTile.label(const Duration(milliseconds: 2500)),
      '2,5 giây',
    );
    expect(ReplyPauseTile.label(const Duration(seconds: 5)), '5 giây');
  });
}
