import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/combo/models/combo_model.dart';
import '../../features/fake_call/models/call_script.dart';
import '../../features/fake_call/services/call_script_runner.dart';
import '../../features/settings/models/app_settings.dart';
import '../../shared/enums/call_interface.dart';
import '../constants/built_in_ringtone.dart';
import 'background_loop.dart';
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
  AudioService(this.files, {BackgroundLoop Function()? createBackground})
    : _createBackground =
          createBackground ??
          (() => JustAudioBackgroundLoop(files, inCall: true));
  final FileService files;
  final BackgroundLoop Function() _createBackground;
  AudioPlayer? _ringtone;
  AudioPlayer? _voice;
  AudioPlayer? _callVoice;
  final _backgrounds = <BackgroundLoop>[];
  FlutterTts? _speech;
  bool _speaking = false;
  final _speechFiles = <String, Future<String?>>{};
  Future<void> _synthesisQueue = Future.value();
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

  /// Phát âm nền rồi hội thoại. `withVoice: false` dùng cho cuộc gọi video
  /// đang phát video người gọi: video đã có tiếng (cả tiếng môi trường lúc
  /// quay), nên chỉ tắt chuông, không phát âm nền chồng lên gây ồn.
  ///
  /// Combo có giọng thu sẵn thì phát cả file một lần. Không thì người gọi nói
  /// từng câu của [script], tới lượt chờ thì gọi [waitForReply] (không có thì
  /// chờ theo thời gian cố định của lượt đó). Âm nền phát ở mức
  /// [backgroundVolume] so với giọng.
  Future<void> conversation(
    ComboModel combo,
    CallScript script, {
    bool withVoice = true,
    ReplyWaiter? waitForReply,
    double backgroundVolume = AppSettings.defaultBackgroundVolume,
  }) async {
    await stop();
    if (!withVoice) {
      return;
    }
    final generation = _generation;
    final sources = backgroundSources(
      combo.backgroundSoundPaths,
      combo.customBackgroundPath,
    );
    for (final source in sources) {
      if (generation != _generation) {
        return;
      }
      final loop = _createBackground();
      _backgrounds.add(loop);
      try {
        await loop.start(source, backgroundVolume);
      } catch (_) {
        // Một âm nền hỏng hoặc mất file thì bỏ qua, cuộc gọi vẫn tiếp tục.
        if (_backgrounds.remove(loop)) {
          unawaited(loop.dispose().catchError((Object _) {}));
        }
      }
    }
    if (generation != _generation) {
      return;
    }
    final voicePath = combo.voicePath;
    if (voicePath != null) {
      try {
        await _playCallVoice(
          AudioSource.uri(Uri.parse(await files.audioUri(voicePath))),
        );
        return;
      } catch (_) {
        // File giọng mất hoặc hỏng: đọc kịch bản để cuộc gọi không im lặng.
        if (generation != _generation) {
          return;
        }
      }
    }
    await CallScriptRunner(
      speak: (line) => _speakLine(line, generation),
      waitForReply:
          waitForReply ?? (fallback) => Future<void>.delayed(fallback),
      isCancelled: () => generation != _generation,
    ).run(script);
  }

  /// Một câu của người gọi: file thoại của câu, không có hoặc lỗi thì giọng
  /// đọc dạng file (đi loa trong), cuối cùng mới đọc trực tiếp ra loa ngoài.
  Future<void> _speakLine(SpeakTurn line, int generation) async {
    final audioPath = line.audioPath;
    if (audioPath != null) {
      try {
        await _playCallVoice(await _lineSource(audioPath));
        return;
      } catch (_) {
        if (generation != _generation) {
          return;
        }
      }
    }
    if (line.text.trim().isEmpty) {
      return;
    }
    final speechFile = await _speechFileFor(line.text);
    if (generation != _generation) {
      return;
    }
    if (speechFile != null) {
      try {
        await _playCallVoice(AudioSource.file(speechFile));
        return;
      } catch (_) {
        if (generation != _generation) {
          return;
        }
      }
    }
    await speak(line.text);
  }

  /// File thoại của kịch bản: tài nguyên có sẵn (`audio/voice/...`), file nhập
  /// từ máy (đường dẫn tuyệt đối) hoặc âm thanh riêng (`media:`).
  Future<AudioSource> _lineSource(String path) async {
    if (path.startsWith('media:')) {
      return AudioSource.uri(Uri.parse(await files.audioUri(path)));
    }
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:') ||
        path.startsWith('blob:')) {
      return AudioSource.uri(Uri.parse(path));
    }
    if (!kIsWeb &&
        (path.startsWith('/') || RegExp(r'^[a-zA-Z]:[\/]').hasMatch(path))) {
      return AudioSource.file(path);
    }
    return AudioSource.asset(
      path.startsWith('assets/') ? path : 'assets/$path',
    );
  }

  /// Tạo trước giọng đọc cho các câu không có file thoại, trong lúc đổ chuông,
  /// để trả lời là nghe ngay. Xóa file của kịch bản trước.
  Future<void> prepareSpeech(CallScript script) async {
    final texts = {
      for (final line in script.lines)
        if (line.audioPath == null && line.text.trim().isNotEmpty) line.text,
    };
    _forgetSpeechExcept(texts);
    await Future.wait(texts.map(_speechFileFor));
  }

  /// Giọng đọc dạng file phát được qua loa trong. Chỉ Android: thư viện đọc
  /// không cho chọn loa, nên đọc ra file rồi phát như giọng thu.
  Future<String?> _speechFileFor(String text) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        text.trim().isEmpty) {
      return Future.value();
    }
    return _speechFiles[text] ??= _queueSynthesis(text);
  }

  /// Máy đọc chỉ tạo được từng file một: câu sau chờ câu trước xong.
  Future<String?> _queueSynthesis(String text) {
    final result = _synthesisQueue.then((_) => _synthesize(text));
    _synthesisQueue = result.then((_) {});
    return result;
  }

  void _forgetSpeechExcept(Set<String> keep) {
    final stale = [
      for (final text in _speechFiles.keys)
        if (!keep.contains(text)) text,
    ];
    for (final text in stale) {
      final file = _speechFiles.remove(text)!;
      unawaited(
        file
            .then((path) async {
              if (path != null) {
                await File(path).delete();
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  Future<String?> _synthesize(String text) async {
    try {
      final speech = _speech ??= FlutterTts();
      await speech.setLanguage('vi-VN');
      await speech.setSpeechRate(0.48);
      await speech.awaitSynthCompletion(true);
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/call_speech_${DateTime.now().microsecondsSinceEpoch}.wav';
      final result = await speech
          .synthesizeToFile(text, path, true)
          .timeout(const Duration(seconds: 10));
      if (result == 1 && await File(path).exists()) {
        return path;
      }
    } catch (_) {
      // Máy không có giọng tiếng Việt hoặc không ghi được file.
    }
    return null;
  }

  /// Giọng người gọi dùng kiểu âm thanh cuộc gọi, nên đi theo loa trong /
  /// loa ngoài mà màn gọi chọn.
  Future<AudioPlayer> _callPlayer() async {
    final player = AudioPlayer(androidApplyAudioAttributes: false);
    await player.setAndroidAudioAttributes(androidCallAudioAttributes);
    return player;
  }

  /// Phát một đoạn giọng người gọi, chờ tới khi phát xong hoặc bị dừng.
  Future<void> _playCallVoice(AudioSource source) async {
    final generation = _generation;
    final voice = _callVoice ??= await _callPlayer();
    await voice.setAudioSource(source);
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
    for (final loop in backgrounds) {
      await loop.dispose().catchError((Object _) {});
    }
  }

  void dispose() {
    _generation++;
    unawaited(_speech?.stop());
    unawaited(_ringtone?.dispose());
    unawaited(_voice?.dispose());
    unawaited(_callVoice?.dispose());
    for (final loop in _backgrounds) {
      unawaited(loop.dispose().catchError((Object _) {}));
    }
  }
}
