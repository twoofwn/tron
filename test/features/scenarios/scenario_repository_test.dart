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
}
