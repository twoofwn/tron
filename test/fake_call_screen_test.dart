import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/app/providers/app_foreground_provider.dart';
import 'package:tron/core/constants/built_in_ringtone.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/activation/services/call_alarm_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/features/fake_call/screens/fake_call_screen.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/settings/providers/settings_provider.dart';
import 'package:tron/shared/enums/call_interface.dart';

class CountingAlarm extends CallAlarmService {
  int cancelled = 0;
  @override
  Future<bool> scheduleCall({
    required String comboId,
    required DateTime fireAt,
    required BuiltInRingtone ringtone,
  }) async => true;
  @override
  Future<void> cancel() async => cancelled++;
}

class RecordingAudioService extends AudioService {
  RecordingAudioService() : super(FileService());
  final events = <String>[];
  final phoneStyles = <PhoneStyle>[];
  @override
  Future<void> stop() async => events.add('stop');
  @override
  Future<void> ring(
    ComboModel combo, {
    PhoneStyle phoneStyle = PhoneStyle.samsung,
  }) async {
    phoneStyles.add(phoneStyle);
    events.add('ring:${combo.callInterface.name}');
  }

  @override
  Future<void> conversation(ComboModel combo, String dialogue) async =>
      events.add('conversation');
  @override
  void dispose() {}
}

void main() {
  Future<RecordingAudioService> open(
    WidgetTester tester,
    CallInterface callInterface, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final audio = RecordingAudioService();
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey(callInterface),
        overrides: [
          audioServiceProvider.overrideWithValue(audio),
          resolvedPhoneStyleProvider.overrideWith(
            (ref) async => PhoneStyle.iphone,
          ),
        ],
        child: MaterialApp(
          home: FakeCallScreen(
            arguments: FakeCallArguments(
              ComboModel(
                id: 'c',
                name: 'Combo',
                scenarioId: 'boss',
                callInterface: callInterface,
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return audio;
  }

  for (final callInterface in CallInterface.values) {
    testWidgets('${callInterface.name} rings, answers and ends', (
      tester,
    ) async {
      final audio = await open(tester, callInterface);
      expect(audio.events, ['ring:${callInterface.name}']);
      expect(find.text('Anh Minh · Công việc'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
      expect(find.text('tắt tiếng'), findsOneWidget);
      expect(audio.events.last, 'conversation');
      // Tắt tiếng chỉ đổi trạng thái, không dừng hội thoại.
      await tester.tap(find.text('tắt tiếng'));
      await tester.pump();
      expect(audio.events.last, 'conversation');
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump();
      expect(audio.events.last, 'stop');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Call screens fit a compact device with large text', (
    tester,
  ) async {
    for (final callInterface in CallInterface.values) {
      await open(
        tester,
        callInterface,
        size: const Size(320, 640),
        textScale: 1.15,
      );
      expect(tester.takeException(), isNull, reason: callInterface.name);
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
      expect(tester.takeException(), isNull, reason: callInterface.name);
    }
  });

  testWidgets('Ringtone follows the phone style from settings', (tester) async {
    final audio = await open(tester, CallInterface.phone);
    expect(audio.phoneStyles, [PhoneStyle.iphone]);
  });

  testWidgets('Locked phone lets the notification ring until the app opens', (
    tester,
  ) async {
    final audio = RecordingAudioService();
    final alarm = CountingAlarm();
    final container = ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWithValue(audio),
        callAlarmServiceProvider.overrideWithValue(alarm),
        resolvedPhoneStyleProvider.overrideWith(
          (ref) async => PhoneStyle.huawei,
        ),
      ],
    );
    addTearDown(container.dispose);
    final combo = ComboModel(
      id: 'c',
      name: 'Combo',
      scenarioId: 'boss',
      callInterface: CallInterface.phone,
      createdAt: DateTime(2026),
    );
    container.read(appForegroundProvider.notifier).setForeground(false);
    container.read(callProvider.notifier).ringNow(combo);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: FakeCallScreen(
            arguments: FakeCallArguments(combo, isPreview: false),
          ),
        ),
      ),
    );
    await tester.pump();
    // Chỉ thông báo hệ thống đổ chuông, app chưa phát gì.
    expect(audio.events, isEmpty);
    final cancelledBefore = alarm.cancelled;

    container.read(appForegroundProvider.notifier).setForeground(true);
    await tester.pump();
    await tester.pump();
    expect(audio.events, ['ring:phone']);
    expect(audio.phoneStyles, [PhoneStyle.huawei]);
    // Thông báo bị tắt để không phát chồng hai chuông.
    expect(alarm.cancelled, greaterThan(cancelledBefore));
  });

  testWidgets('Phone and Messenger message buttons decline the call', (
    tester,
  ) async {
    for (final (callInterface, label) in [
      (CallInterface.phone, 'Tin nhắn'),
      (CallInterface.messenger, 'Nhắn tin'),
    ]) {
      final audio = await open(tester, callInterface);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(audio.events.last, 'stop', reason: callInterface.name);
    }
  });
}
