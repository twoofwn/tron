import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test(
    'samples can be edited in place, hidden, restored and shown again',
    () async {
      SharedPreferences.setMockInitialValues({});
      final documents = await Directory.systemTemp.createTemp('tron-edit-');
      try {
        final repository = ScenarioRepository(
          documentsDirectory: () async => documents,
        );
        await repository.load();
        final ids = repository.scenarios.map((item) => item.id).toList();
        final sample = repository.findScenario('boss-server')!;

        // Sửa kịch bản mẫu: bản sửa cùng ID, đứng đúng chỗ của bản gốc.
        final recorded = File('${documents.path}/escapehatch/audio/b.wav')
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3]);
        final edited = sample.copyWith(
          title: 'Sếp đã sửa',
          source: ScenarioSource.user,
          steps: [
            sample.steps.first.copyWith(audioPath: recorded.path),
            ...sample.steps.skip(1),
          ],
        );
        await repository.saveUserScenario(edited);
        expect(repository.scenarios.map((item) => item.id), ids);
        expect(repository.findScenario('boss-server')?.title, 'Sếp đã sửa');
        expect(repository.isEditedBuiltIn(edited), isTrue);

        // Khôi phục bản gốc: bỏ bản sửa và file giọng đã thu cho nó.
        await repository.restoreBuiltIn(edited);
        expect(repository.findScenario('boss-server')?.title, sample.title);
        expect(recorded.existsSync(), isFalse);

        // Xoá kịch bản mẫu chỉ ẩn khỏi kho; combo vẫn tìm thấy nó.
        await repository.deleteScenario(sample);
        expect(
          repository.scenarios.any((item) => item.id == sample.id),
          isFalse,
        );
        expect(repository.findScenario(sample.id), isNotNull);
        expect(repository.hiddenBuiltInCount, 1);
        repository.dispose();

        // Vẫn ẩn sau khi mở lại app.
        final reopened = ScenarioRepository(
          documentsDirectory: () async => documents,
        );
        await reopened.load();
        expect(reopened.hiddenBuiltInCount, 1);
        await reopened.showHiddenBuiltIns();
        expect(reopened.scenarios.map((item) => item.id), ids);

        // Kịch bản cá nhân bị xoá hẳn.
        final personal = sample.copyWith(
          id: 'user-1',
          source: ScenarioSource.user,
        );
        await reopened.saveUserScenario(personal);
        await reopened.deleteScenario(personal);
        expect(reopened.findScenario('user-1'), isNull);
        expect(reopened.hiddenBuiltInCount, 0);
        reopened.dispose();
      } finally {
        await documents.delete(recursive: true);
      }
    },
  );

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
