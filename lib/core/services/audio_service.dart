import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/combo/models/combo_model.dart';
import '../../features/settings/models/app_settings.dart';
import '../../shared/enums/call_interface.dart';
import '../constants/asset_paths.dart';
import '../constants/built_in_ringtone.dart';
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
  AudioPlayer? _voice;
  AudioPlayer? _callVoice;
  final _backgrounds = <AudioPlayer>[];
  FlutterTts? _speech;
  bool _speaking = false;
  String? _speechText;
  Future<String?>? _speechFile;
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
    _speaking = true;
    try {
      final result = await speech.speak(dialogue);
      if (result == 0) {
        throw StateError('Thiết bị chưa hỗ trợ giọng đọc tiếng Việt.');
      }
    } finally {
      _speaking = false;
    }
  }

  /// Đổ chuông lặp lại tới khi [stop]. [phoneStyle] chọn chuông cho giao diện
  /// Điện thoại (iPhone, Samsung, Huawei).
  Future<void> ring(
    ComboModel combo, {
    PhoneStyle phoneStyle = PhoneStyle.samsung,
  }) async {
    await stop();
    final generation = _generation;
    final ringtone = _ringtone ??= AudioPlayer();
    if (combo.ringtoneType == RingtoneType.custom &&
        combo.ringtonePath != null) {
      await ringtone.setUrl(await files.audioUri(combo.ringtonePath!));
    } else {
      final builtIn = BuiltInRingtone.resolve(
        type: combo.ringtoneType,
        callInterface: combo.callInterface,
        phoneStyle: phoneStyle,
      );
      await ringtone.setAsset(builtIn.asset);
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
      final player = await _callPlayer();
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
    final voicePath = combo.voicePath;
    if (voicePath != null) {
      try {
        await _playCallVoice(Uri.parse(await files.audioUri(voicePath)));
        return;
      } catch (_) {
        // File giọng mất hoặc hỏng: đọc kịch bản để cuộc gọi không im lặng.
        if (generation != _generation) {
          return;
        }
      }
    }
    final speechFile = await _speechFileFor(dialogue);
    if (generation != _generation) {
      return;
    }
    if (speechFile != null) {
      try {
        await _playCallVoice(Uri.file(speechFile));
        return;
      } catch (_) {
        if (generation != _generation) {
          return;
        }
      }
    }
    // Không tạo được file giọng đọc: đọc trực tiếp, chỉ ra được loa ngoài.
    await speak(dialogue);
  }

  /// Tạo trước file giọng đọc trong lúc đổ chuông để trả lời là nghe ngay.
  Future<void> prepareSpeech(String dialogue) async {
    await _speechFileFor(dialogue);
  }

  /// Giọng đọc dạng file phát được qua loa trong. Chỉ Android: thư viện đọc
  /// không cho chọn loa, nên đọc ra file rồi phát như giọng thu.
  Future<String?> _speechFileFor(String dialogue) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        dialogue.trim().isEmpty) {
      return Future.value();
    }
    if (_speechText != dialogue || _speechFile == null) {
      final previous = _speechFile;
      _speechText = dialogue;
      _speechFile = _synthesize(dialogue);
      // Xóa file của kịch bản trước, không để thư mục tạm đầy dần.
      unawaited(
        previous
            ?.then((path) async {
              if (path != null) {
                await File(path).delete();
              }
            })
            .catchError((Object _) {}),
      );
    }
    return _speechFile!;
  }

  Future<String?> _synthesize(String dialogue) async {
    try {
      final speech = _speech ??= FlutterTts();
      await speech.setLanguage('vi-VN');
      await speech.setSpeechRate(0.48);
      await speech.awaitSynthCompletion(true);
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/call_speech_${DateTime.now().microsecondsSinceEpoch}.wav';
      final result = await speech
          .synthesizeToFile(dialogue, path, true)
          .timeout(const Duration(seconds: 10));
      if (result == 1 && await File(path).exists()) {
        return path;
      }
    } catch (_) {
      // Máy không có giọng tiếng Việt hoặc không ghi được file.
    }
    return null;
  }

  /// Giọng và âm nền của người gọi dùng kiểu âm thanh cuộc gọi, nên đi theo
  /// loa trong / loa ngoài mà màn gọi chọn.
  Future<AudioPlayer> _callPlayer() async {
    final player = AudioPlayer(androidApplyAudioAttributes: false);
    await player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        usage: AndroidAudioUsage.voiceCommunication,
        contentType: AndroidAudioContentType.speech,
      ),
    );
    return player;
  }

  Future<void> _playCallVoice(Uri uri) async {
    final generation = _generation;
    final voice = _callVoice ??= await _callPlayer();
    await voice.setAudioSource(AudioSource.uri(uri));
    if (generation != _generation) {
      return;
    }
    await voice.setLoopMode(LoopMode.off);
    if (generation != _generation) {
      return;
    }
    await voice.play();
  }

  /// Phát giọng người gọi đã thu một lần, chờ tới khi phát xong hoặc bị dừng.
  Future<void> playVoice(String path) async {
    final generation = _generation;
    final voice = _voice ??= AudioPlayer();
    await voice.setUrl(await files.audioUri(path));
    if (generation != _generation) {
      return;
    }
    await voice.setLoopMode(LoopMode.off);
    if (generation != _generation) {
      return;
    }
    await voice.play();
  }

  Future<void> stop() async {
    _generation++;
    final backgrounds = [..._backgrounds];
    _backgrounds.clear();
    // Chỉ dừng khi đang đọc: lệnh dừng cũng cắt ngang việc tạo file giọng đọc.
    if (_speaking) {
      await _speech?.stop();
    }
    await _ringtone?.stop();
    await _voice?.stop();
    await _callVoice?.stop();
    for (final player in backgrounds) {
      await player.dispose();
    }
  }

  void dispose() {
    _generation++;
    unawaited(_speech?.stop());
    unawaited(_ringtone?.dispose());
    unawaited(_voice?.dispose());
    unawaited(_callVoice?.dispose());
    for (final player in _backgrounds) {
      unawaited(player.dispose());
    }
  }
}
