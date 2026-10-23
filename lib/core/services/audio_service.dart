import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/combo/models/combo_model.dart';
import '../../shared/enums/call_interface.dart';
import '../constants/asset_paths.dart';
import 'file_service.dart';

final audioServiceProvider = Provider((ref) {
  final service = AudioService(ref.watch(fileServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});
final scenarioPlaybackProvider =
    NotifierProvider<ScenarioPlaybackNotifier, bool>(
      ScenarioPlaybackNotifier.new,
    );

class ScenarioPlaybackNotifier extends Notifier<bool> {
  int _generation = 0;
  @override
  bool build() => false;
  Future<void> play(String dialogue) async {
    await stop();
    final generation = _generation;
    state = true;
    try {
      await ref.read(audioServiceProvider).speak(dialogue);
    } finally {
      if (ref.mounted && generation == _generation) {
        state = false;
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    if (state) {
      await ref.read(audioServiceProvider).stop();
    }
    if (ref.mounted) {
      state = false;
    }
  }
}

class AudioService {
  AudioService(this.files);
  final FileService files;
  AudioPlayer? _ringtone;
  final _backgrounds = <AudioPlayer>[];
  FlutterTts? _speech;
  int _generation = 0;

  Future<void> speak(String dialogue) async {
    final generation = _generation;
    final speech = _speech ??= FlutterTts();
    await speech.setLanguage('vi-VN');
    await speech.setSpeechRate(0.48);
    await speech.awaitSpeakCompletion(true);
    if (generation != _generation) {
      return;
    }
    final result = await speech.speak(dialogue);
    if (result == 0) {
      throw StateError('Thiết bị chưa hỗ trợ giọng đọc tiếng Việt.');
    }
  }

  Future<void> ring(ComboModel combo) async {
    await stop();
    final generation = _generation;
    final ringtone = _ringtone ??= AudioPlayer();
    if (combo.ringtoneType == RingtoneType.custom &&
        combo.ringtonePath != null) {
      await ringtone.setUrl(await files.audioUri(combo.ringtonePath!));
    } else {
      final asset = combo.ringtoneType == RingtoneType.classic
          ? AssetPaths.ringtone
          : 'assets/audio/ringtones/${combo.callInterface.name}_ring.wav';
      await ringtone.setAsset(asset);
    }
    if (generation != _generation) {
      return;
    }
    await ringtone.setLoopMode(LoopMode.one);
    if (generation != _generation) {
      return;
    }
    unawaited(ringtone.play().catchError((Object _) {}));
  }

  Future<void> conversation(ComboModel combo, String dialogue) async {
    await stop();
    final generation = _generation;
    final sources = [
      for (final key in combo.backgroundSoundPaths)
        AssetPaths.backgrounds[key]!,
      if (combo.customBackgroundPath != null) combo.customBackgroundPath!,
    ];
    for (final source in sources) {
      if (generation != _generation) {
        return;
      }
      final player = AudioPlayer();
      _backgrounds.add(player);
      if (source.startsWith('media:')) {
        await player.setUrl(await files.audioUri(source));
      } else {
        await player.setAsset(source);
      }
      await player.setVolume(0.18);
      await player.setLoopMode(LoopMode.one);
      if (generation != _generation) {
        return;
      }
      unawaited(player.play().catchError((Object _) {}));
    }
    if (generation != _generation) {
      return;
    }
    await speak(dialogue);
  }

  Future<void> stop() async {
    _generation++;
    final backgrounds = [..._backgrounds];
    _backgrounds.clear();
    await _speech?.stop();
    await _ringtone?.stop();
    for (final player in backgrounds) {
      await player.dispose();
    }
  }

  void dispose() {
    _generation++;
    unawaited(_speech?.stop());
    unawaited(_ringtone?.dispose());
    for (final player in _backgrounds) {
      unawaited(player.dispose());
    }
  }
}
