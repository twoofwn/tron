import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/background_preview.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/models/call_script.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/shared/enums/call_interface.dart';

import 'fake_background_loop.dart';

ComboModel combo({List<String> backgrounds = const [], String? custom}) =>
    ComboModel(
      id: 'c1',
      name: 'Thử âm nền',
      scenarioId: 'mother',
      callInterface: CallInterface.phone,
      createdAt: DateTime(2026),
      backgroundSoundPaths: backgrounds,
      customBackgroundPath: custom,
    );

void main() {
  group('Call backgrounds', () {
    test('play every background at the chosen volume until stop', () async {
      final loops = LoopFactory();
      final audio = AudioService(FileService(), createBackground: loops.call);
      await audio.conversation(
        combo(backgrounds: ['traffic', 'rain'], custom: 'media:mine.mp3'),
        const CallScript([]),
        backgroundVolume: 0.8,
      );
      expect(loops.loops.map((loop) => loop.source), [
        'traffic',
        'rain',
        'media:mine.mp3',
      ]);
      expect(loops.loops.map((loop) => loop.volume), everyElement(0.8));
      expect(loops.loops.any((loop) => loop.disposed), isFalse);

      await audio.stop();
      expect(loops.loops.every((loop) => loop.disposed), isTrue);
    });

    test('a broken background is skipped, the others keep playing', () async {
      final loops = LoopFactory(brokenSources: {0});
      final audio = AudioService(FileService(), createBackground: loops.call);
      await audio.conversation(
        combo(backgrounds: ['dog', 'rain']),
        const CallScript([]),
      );
      expect(loops.loops.first.disposed, isTrue);
      expect(loops.loops.last.source, 'rain');
      expect(loops.loops.last.volume, AppSettings.defaultBackgroundVolume);
      expect(loops.loops.last.disposed, isFalse);
      await audio.stop();
    });

    test('video calls play no background', () async {
      final loops = LoopFactory();
      final audio = AudioService(FileService(), createBackground: loops.call);
      await audio.conversation(
        combo(backgrounds: ['traffic']),
        const CallScript([]),
        withVoice: false,
      );
      expect(loops.loops, isEmpty);
    });
  });

  group('Background preview', () {
    late LoopFactory loops;
    late ProviderContainer container;

    setUp(() {
      loops = LoopFactory();
      container = ProviderContainer(
        overrides: [
          backgroundPreviewLoopProvider.overrideWithValue(loops.call),
        ],
      );
      addTearDown(container.dispose);
    });

    BackgroundPreviewNotifier preview() =>
        container.read(backgroundPreviewProvider.notifier);

    test('plays the selection, follows the slider and stops', () async {
      await preview().play(['office', 'traffic'], 0.5);
      expect(container.read(backgroundPreviewProvider), isTrue);
      expect(loops.loops.map((loop) => loop.source), ['office', 'traffic']);

      await preview().setVolume(0.9);
      expect(loops.loops.map((loop) => loop.volume), everyElement(0.9));

      await preview().stop();
      expect(container.read(backgroundPreviewProvider), isFalse);
      expect(loops.loops.every((loop) => loop.disposed), isTrue);
    });

    test('playing a new selection replaces the old one', () async {
      await preview().play(['office'], 0.5);
      await preview().play(['rain'], 0.5);
      expect(loops.loops.first.disposed, isTrue);
      expect(loops.loops.last.source, 'rain');
      expect(loops.loops.last.disposed, isFalse);
    });

    test('nothing playable reports an error and resets', () async {
      loops = LoopFactory(brokenSources: {0});
      container = ProviderContainer(
        overrides: [
          backgroundPreviewLoopProvider.overrideWithValue(loops.call),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(preview().play(['dog'], 0.5), throwsStateError);
      expect(container.read(backgroundPreviewProvider), isFalse);
    });

    test('disposing the app stops the preview', () async {
      await preview().play(['rain'], 0.5);
      container.dispose();
      expect(loops.loops.single.disposed, isTrue);
    });
  });

  group('Background volume setting', () {
    test('defaults, round-trips and stays audible', () {
      expect(
        const AppSettings().backgroundVolume,
        AppSettings.defaultBackgroundVolume,
      );
      final saved = const AppSettings().copyWith(backgroundVolume: 0.3);
      expect(AppSettings.fromJson(saved.toJson()).backgroundVolume, 0.3);
      expect(
        const AppSettings().copyWith(backgroundVolume: 0).backgroundVolume,
        AppSettings.minBackgroundVolume,
      );
      expect(AppSettings.fromJson({'backgroundVolume': 4}).backgroundVolume, 1);
      expect(
        AppSettings.fromJson({'backgroundVolume': 'to'}).backgroundVolume,
        AppSettings.defaultBackgroundVolume,
      );
    });
  });
}
