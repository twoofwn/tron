import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/voice_recorder.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/scenarios/presentation/scenario_editor_sheet.dart';
import 'package:tron/features/scenarios/services/scenario_preview_player.dart';

/// Kho kịch bản trong bộ nhớ: không ghi file thật.
class MemoryRepository extends ScenarioRepository {
  var _next = 0;
  final deleted = <String>[];
  Scenario? saved;

  @override
  Future<String> importAudio(Uint8List bytes, String originalName) async =>
      '/docs/escapehatch/audio/take-${_next++}.wav';

  @override
  Future<void> deleteAudio(String path) async => deleted.add(path);

  @override
  Future<void> saveUserScenario(Scenario scenario) async => saved = scenario;
}

class FakeLineRecorder extends VoiceRecorder {
  FakeLineRecorder({this.allowed = true}) : super(FileService());
  final bool allowed;
  final events = <String>[];

  @override
  Future<bool> start() async {
    events.add('start');
    return allowed;
  }

  @override
  Future<Uint8List?> stopBytes() async {
    events.add('stop');
    return Uint8List(40000);
  }

  @override
  Future<void> cancel() async => events.add('cancel');

  @override
  void dispose() {}
}

class FakePlayer implements PreviewAudioBackend {
  final played = <String>[];
  int stops = 0;
  Completer<void>? _playing;

  @override
  Future<void> playVoice(String path) {
    played.add(path);
    return (_playing = Completer<void>()).future;
  }

  @override
  Future<void> playBackground(String path, double volume) async {}

  @override
  Future<void> stop() async {
    stops++;
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
  }

  @override
  Future<void> dispose() => stop();
}

DialogueStep _say(String id, String text, String audio) => DialogueStep(
  id: id,
  type: DialogueStepType.speech,
  text: text,
  audioPath: audio,
  seconds: 2,
);

DialogueStep _wait(String id) =>
    DialogueStep(id: id, type: DialogueStepType.wait, text: 'Bạn trả lời');

Scenario _scenario({
  ScenarioSource source = ScenarioSource.builtIn,
  String prefix = 'audio/voice/mother_',
}) => Scenario(
  id: source == ScenarioSource.user ? 'user-1' : 'mother-urgent',
  title: 'Mẹ gọi về gấp',
  category: ScenarioCategory.family,
  source: source,
  callerName: 'Mẹ',
  initial: 'M',
  defaultBackgroundId: 'television',
  steps: [
    _say('m1', 'Alo, con à?', '${prefix}1.wav'),
    _wait('w1'),
    _say('m2', 'Về ngay nhé.', '${prefix}2.wav'),
    _wait('w2'),
    _say('m3', 'Bố con đang mệt.', '${prefix}3.wav'),
    _say('m4', 'Nhanh lên nhé con.', '${prefix}4.wav'),
  ],
);

class _Harness {
  _Harness(this.repository, this.recorder, this.player);
  final MemoryRepository repository;
  final FakeLineRecorder recorder;
  final FakePlayer player;
  Scenario? result;
  bool closed = false;
}

Future<_Harness> _open(
  WidgetTester tester, {
  Scenario? original,
  bool allowed = true,
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = _Harness(
    MemoryRepository(),
    FakeLineRecorder(allowed: allowed),
    FakePlayer(),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              harness.result = await showScenarioEditor(
                context,
                repository: harness.repository,
                original: original,
                recorder: harness.recorder,
                player: harness.player,
              );
              harness.closed = true;
            },
            child: const Text('Mở form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở form'));
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _record(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(OutlinedButton, label).first);
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(find.textContaining('Dừng 00:0'));
  await tester.pump();
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Lưu kịch bản'));
  await tester.pumpAndSettle();
}

List<DialogueStepType> _types(Scenario scenario) =>
    scenario.steps.map((step) => step.type).toList();

void main() {
  testWidgets('a copied sample keeps its turns and sample voices', (
    tester,
  ) async {
    final h = await _open(tester, original: _scenario());
    expect(find.text('Sao chép kịch bản'), findsOneWidget);
    expect(find.textContaining('Giọng mẫu của app'), findsNWidgets(4));
    // Câu 3 nói liền câu 4 nên không chờ; câu cuối không có ô chờ.
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((tile) => tile.value)
        .toList();
    expect(boxes, [true, true, false]);

    await _save(tester);
    final saved = h.repository.saved!;
    expect(saved.id, startsWith('user-'));
    expect(saved.source, ScenarioSource.user);
    expect(_types(saved), [
      DialogueStepType.speech,
      DialogueStepType.wait,
      DialogueStepType.speech,
      DialogueStepType.wait,
      DialogueStepType.speech,
      DialogueStepType.speech,
    ]);
    // Bản sao không bao giờ xoá audio của kịch bản mẫu.
    expect(h.repository.deleted, isEmpty);
    expect(h.result?.id, saved.id);
  });

  testWidgets('recording a line replaces the sample voice', (tester) async {
    final h = await _open(tester, original: _scenario());
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thu lại').first);
    await tester.pump();
    expect(h.recorder.events, ['start']);
    expect(find.textContaining('Đang thu 00:00'), findsOneWidget);
    expect(find.text('Đang thu giọng...'), findsOneWidget);
    // Đang thu câu 1 thì không thu được câu khác.
    final others = tester
        .widgetList<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Thu lại'),
        )
        .where((button) => button.onPressed != null);
    expect(others, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Dừng 00:03'), findsOneWidget);
    await tester.tap(find.text('Dừng 00:03'));
    await tester.pump();
    await tester.pump();
    expect(h.recorder.events, ['start', 'stop']);
    expect(find.text('Giọng tự thu'), findsOneWidget);
    expect(find.textContaining('Giọng mẫu của app'), findsNWidgets(3));

    await _save(tester);
    expect(
      h.repository.saved!.steps.first.audioPath,
      '/docs/escapehatch/audio/take-0.wav',
    );
  });

  testWidgets('a second take deletes the first one', (tester) async {
    final h = await _open(tester, original: _scenario());
    await _record(tester, 'Thu lại');
    await _record(tester, 'Thu lại');
    expect(h.repository.deleted, ['/docs/escapehatch/audio/take-0.wav']);
    await _save(tester);
    expect(
      h.repository.saved!.steps.first.audioPath,
      '/docs/escapehatch/audio/take-1.wav',
    );
    expect(h.repository.deleted, ['/docs/escapehatch/audio/take-0.wav']);
  });

  testWidgets('closing without saving deletes the new takes', (tester) async {
    final h = await _open(tester, original: _scenario());
    await _record(tester, 'Thu lại');
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(h.closed, isTrue);
    expect(h.result, isNull);
    expect(h.repository.saved, isNull);
    expect(h.repository.deleted, ['/docs/escapehatch/audio/take-0.wav']);
  });

  testWidgets('a denied mic explains how to allow it', (tester) async {
    final h = await _open(tester, original: _scenario(), allowed: false);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thu lại').first);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Cần quyền micro'), findsOneWidget);
    expect(find.textContaining('Đang thu'), findsNothing);
    expect(h.repository.deleted, isEmpty);
  });

  testWidgets('a take stops by itself after 30 seconds', (tester) async {
    final h = await _open(tester, original: _scenario());
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thu lại').first);
    await tester.pump();
    for (var second = 0; second < 25; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('còn 5 giây'), findsOneWidget);
    for (var second = 0; second < 6; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(h.recorder.events, ['start', 'stop']);
    expect(find.text('Giọng tự thu'), findsOneWidget);
    expect(find.textContaining('Đã đủ 30 giây'), findsOneWidget);
  });

  testWidgets('a line can be played back and stopped', (tester) async {
    final h = await _open(tester, original: _scenario());
    await tester.tap(find.byTooltip('Nghe câu 2'));
    await tester.pump();
    expect(h.player.played, ['audio/voice/mother_2.wav']);
    expect(find.byTooltip('Dừng nghe câu 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Dừng nghe câu 2'));
    await tester.pump();
    expect(find.byTooltip('Nghe câu 2'), findsOneWidget);
    // Bấm thu thì giọng đang phát bị tắt.
    await tester.tap(find.byTooltip('Nghe câu 1'));
    await tester.pump();
    final stops = h.player.stops;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thu lại').first);
    await tester.pump();
    expect(h.player.stops, greaterThan(stops));
  });

  testWidgets('changed text needs a new take before saving', (tester) async {
    final h = await _open(tester, original: _scenario());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Alo, con à?'),
      'Alo, con ơi?',
    );
    await _save(tester);
    expect(find.textContaining('Thu lại hoặc chọn file mới'), findsOneWidget);
    expect(h.repository.saved, isNull);

    await _record(tester, 'Thu lại');
    await _save(tester);
    expect(h.repository.saved!.steps.first.text, 'Alo, con ơi?');
  });

  testWidgets('editing a personal scenario cleans up replaced audio', (
    tester,
  ) async {
    final original = _scenario(
      source: ScenarioSource.user,
      prefix: '/docs/escapehatch/audio/old-',
    );
    final h = await _open(tester, original: original);
    expect(find.text('Sửa kịch bản'), findsOneWidget);
    await _record(tester, 'Thu lại');
    await tester.tap(find.byTooltip('Xóa câu 4'));
    await tester.pump();
    await _save(tester);
    expect(h.repository.saved!.id, 'user-1');
    expect(h.repository.deleted.toSet(), {
      '/docs/escapehatch/audio/old-1.wav',
      '/docs/escapehatch/audio/old-4.wav',
    });
  });

  testWidgets('a new scenario records every line and can skip a wait', (
    tester,
  ) async {
    final h = await _open(tester);
    expect(find.text('Chưa có giọng'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên kịch bản'),
      'Bạn gọi',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên người gọi hiển thị'),
      'Lan',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Ê, ra đây.');
    await _save(tester);
    expect(find.textContaining('Câu 1 chưa có giọng'), findsOneWidget);

    await _record(tester, 'Thu giọng');
    await tester.tap(find.text('Thêm câu thoại'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(3), 'Nhanh nhé.');
    await _record(tester, 'Thu giọng');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _save(tester);
    final saved = h.repository.saved!;
    expect(_types(saved), [DialogueStepType.speech, DialogueStepType.speech]);
    expect(saved.steps.map((step) => step.audioPath), [
      '/docs/escapehatch/audio/take-0.wav',
      '/docs/escapehatch/audio/take-1.wav',
    ]);
  });
}
