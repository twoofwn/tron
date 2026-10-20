import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/scenarios/services/scenario_preview_player.dart';

class _FakeAudioBackend implements PreviewAudioBackend {
  Completer<void>? playing;
  int stopCount = 0;

  @override
  Future<void> playVoice(String path) {
    playing = Completer<void>();
    return playing!.future;
  }

  @override
  Future<void> playBackground(String path, double volume) async {}

  @override
  Future<void> stop() async {
    stopCount++;
    final pending = playing;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'stopping preview interrupts the current line and clears state',
    () async {
      final backend = _FakeAudioBackend();
      final player = ScenarioPreviewPlayer(backend: backend);
      const scenario = Scenario(
        id: 'test',
        title: 'Test',
        category: ScenarioCategory.family,
        source: ScenarioSource.builtIn,
        callerName: 'Mẹ',
        initial: 'M',
        defaultBackgroundId: null,
        steps: [
          DialogueStep(
            id: 'line1',
            type: DialogueStepType.speech,
            text: 'Hello',
            audioPath: 'audio/voice/test.wav',
            seconds: 1,
          ),
        ],
      );

      final playing = player.start(scenario);
      await Future<void>.delayed(Duration.zero);
      expect(player.isPlaying, isTrue);
      expect(player.activeStepId, 'line1');
      await player.stop();
      await playing;
      expect(player.isPlaying, isFalse);
      expect(player.activeStepId, isNull);
      expect(player.error, isNull);
      expect(backend.stopCount, greaterThanOrEqualTo(2));
      await player.close();
    },
  );
}
