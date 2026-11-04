import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/constants/asset_paths.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

void main() {
  test('Every call background option has a bundled file', () {
    for (final sound in BackgroundSound.values) {
      final path = AssetPaths.backgrounds[sound.name];
      expect(path, isNotNull, reason: sound.name);
      expect(File(path!).existsSync(), isTrue, reason: path);
    }
  });

  test('Every scenario library background has a bundled file', () {
    for (final sound in ScenarioRepository.bundledBackgrounds) {
      final path = 'assets/${sound.audioPath}';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('Call and scenario library share the recorded MP3 backgrounds', () {
    const shared = {'office': 'office', 'traffic': 'car', 'rain': 'rain'};
    final library = {
      for (final sound in ScenarioRepository.bundledBackgrounds)
        sound.id: 'assets/${sound.audioPath}',
    };
    shared.forEach((callKey, libraryId) {
      expect(AssetPaths.backgrounds[callKey], endsWith('.mp3'));
      expect(library[libraryId], AssetPaths.backgrounds[callKey]);
    });
    expect(library['dog'], 'assets/audio/backgrounds/dog.mp3');
  });
}
