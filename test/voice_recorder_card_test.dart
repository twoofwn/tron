import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/voice_recorder.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/widgets/voice_recorder_card.dart';
import 'package:tron/shared/enums/call_interface.dart';

class FakeRecorder extends VoiceRecorder {
  FakeRecorder({this.allowed = true}) : super(FileService());
  final bool allowed;
  final events = <String>[];
  @override
  Future<bool> start() async {
    events.add('start');
    return allowed;
  }

  @override
  Future<String?> stop() async {
    events.add('stop');
    return 'media:0f0f.wav';
  }

  @override
  Future<void> cancel() async => events.add('cancel');
}

class FakeAudio extends AudioService {
  FakeAudio() : super(FileService());
  final played = <String>[];
  @override
  Future<void> playVoice(String path) async => played.add(path);
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

void main() {
  Future<({FakeRecorder recorder, FakeAudio audio, List<String?> changes})>
  pump(WidgetTester tester, {bool allowed = true, String? voicePath}) async {
    final recorder = FakeRecorder(allowed: allowed);
    final audio = FakeAudio();
    final changes = <String?>[];
    String? current = voicePath;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceRecorderProvider.overrideWithValue(recorder),
          audioServiceProvider.overrideWithValue(audio),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => VoiceRecorderCard(
                voicePath: current,
                onChanged: (path) => setState(() {
                  current = path;
                  changes.add(path);
                }),
                onRecordingChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    return (recorder: recorder, audio: audio, changes: changes);
  }

  testWidgets('Records, saves, plays back and deletes the caller voice', (
    tester,
  ) async {
    final r = await pump(tester);
    expect(find.text('Giọng người gọi'), findsOneWidget);
    await tester.tap(find.text('Thu giọng'));
    await tester.pump();
    expect(find.textContaining('Đang thu'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('00:03'), findsOneWidget);
    await tester.tap(find.byTooltip('Dừng và lưu'));
    await tester.pump();
    expect(r.recorder.events, ['start', 'stop']);
    expect(r.changes, ['media:0f0f.wav']);
    expect(find.text('Giọng tự thu'), findsOneWidget);
    await tester.tap(find.byTooltip('Nghe lại'));
    await tester.pump();
    expect(r.audio.played, ['media:0f0f.wav']);
    await tester.tap(find.byTooltip('Xoá giọng tự thu'));
    await tester.pump();
    expect(r.changes.last, isNull);
    expect(find.text('Giọng người gọi'), findsOneWidget);
  });

  testWidgets('Cancel discards the take', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Thu giọng'));
    await tester.pump();
    await tester.tap(find.byTooltip('Huỷ bản thu'));
    await tester.pump();
    expect(r.recorder.events, ['start', 'cancel']);
    expect(r.changes, isEmpty);
  });

  testWidgets('Stops by itself at the time limit', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Thu giọng'));
    await tester.pump();
    await tester.pump(VoiceRecorder.maxDuration);
    await tester.pump();
    expect(r.recorder.events, ['start', 'stop']);
    expect(r.changes, ['media:0f0f.wav']);
  });

  testWidgets('Explains when microphone permission is denied', (tester) async {
    final r = await pump(tester, allowed: false);
    await tester.tap(find.text('Thu giọng'));
    await tester.pump();
    expect(find.textContaining('Cần quyền micro'), findsOneWidget);
    expect(find.textContaining('Đang thu'), findsNothing);
    expect(r.changes, isEmpty);
  });

  test(
    'Voice path survives save and load, and is stripped with custom audio',
    () {
      final combo = ComboModel(
        id: 'c',
        name: 'Mẹ',
        scenarioId: 'mother',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
        voicePath: 'media:0f0f.wav',
      );
      expect(ComboModel.fromJson(combo.toJson()).voicePath, 'media:0f0f.wav');
      expect(combo.copyWith(stripCustomAudio: true).voicePath, isNull);
      expect(combo.customAudioPaths, ['media:0f0f.wav']);
      expect(Uint8List(0), isEmpty);
    },
  );
}
