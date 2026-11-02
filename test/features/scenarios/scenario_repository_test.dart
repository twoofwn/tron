import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/scenarios/models/scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled audio exists and personal scenarios persist across loads',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'tron-scenarios-',
      );
      try {
        final first = ScenarioRepository(
          documentsDirectory: () async => documents,
        );
        await first.load();
        expect(first.scenarios.length, greaterThanOrEqualTo(4));
        for (final scenario in first.scenarios) {
          for (final step in scenario.steps) {
            if (step.type == DialogueStepType.speech) {
              final bytes = await rootBundle.load('assets/${step.audioPath}');
              expect(bytes.lengthInBytes, greaterThan(4096));
            }
          }
        }
        final personal = first.scenarios.first.copyWith(
          id: 'user-test',
          title: 'Kịch bản của tôi',
          source: ScenarioSource.user,
        );
        await first.saveUserScenario(personal);
        await first.saveUserScenario(
          personal.copyWith(title: 'Kịch bản đã sửa'),
        );
        first.dispose();

        final second = ScenarioRepository(
          documentsDirectory: () async => documents,
        );
        await second.load();
        expect(second.findScenario('user-test')?.title, 'Kịch bản đã sửa');
        second.dispose();
      } finally {
        await documents.delete(recursive: true);
      }
    },
  );

  test('only recorded or imported audio files can be deleted', () async {
    final documents = await Directory.systemTemp.createTemp('tron-audio-');
    final outside = File('${documents.path}/keep.wav')
      ..writeAsBytesSync([1, 2, 3]);
    try {
      final repository = ScenarioRepository(
        documentsDirectory: () async => documents,
      );
      final path = await repository.importAudio(
        Uint8List.fromList(List.filled(64, 1)),
        'cau.wav',
      );
      expect(File(path).existsSync(), isTrue);
      expect(ScenarioRepository.isBundledAudio(path), isFalse);

      await repository.deleteAudio(path);
      expect(File(path).existsSync(), isFalse);
      // File ngoài thư mục audio của kho kịch bản không bao giờ bị xoá.
      await repository.deleteAudio(outside.path);
      await repository.deleteAudio(
        '${documents.path}/escapehatch/audio/../../keep.wav',
      );
      await repository.deleteAudio('audio/voice/mother_1.wav');
      expect(outside.existsSync(), isTrue);
      repository.dispose();
    } finally {
      await documents.delete(recursive: true);
    }
  });

  test('bundled audio is told apart from user audio', () {
    expect(
      ScenarioRepository.isBundledAudio('audio/voice/mother_1.wav'),
      isTrue,
    );
    for (final path in [
      '/data/user/0/app/escapehatch/audio/1.wav',
      r'C:\Users\a\escapehatch\audio\1.wav',
      'data:audio/wav;base64,AAAA',
      'media:abc.wav',
      'https://example.com/a.wav',
    ]) {
      expect(ScenarioRepository.isBundledAudio(path), isFalse, reason: path);
    }
  });
}
