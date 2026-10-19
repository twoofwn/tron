import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/screens/fake_call_screen.dart';
import 'package:tron/shared/enums/call_interface.dart';

class RecordingAudioService extends AudioService {
  RecordingAudioService() : super(FileService());
  final events = <String>[];
  @override
  Future<void> stop() async => events.add('stop');
  @override
  Future<void> ring(ComboModel combo) async =>
      events.add('ring:${combo.callInterface.name}');
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
        overrides: [audioServiceProvider.overrideWithValue(audio)],
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
