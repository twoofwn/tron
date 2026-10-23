import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/scenario.dart';

abstract class PreviewAudioBackend {
  Future<void> playVoice(String path);
  Future<void> playBackground(String path, double volume);
  Future<void> stop();
  Future<void> dispose();
}

class DevicePreviewAudioBackend implements PreviewAudioBackend {
  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _background = AudioPlayer();
  StreamSubscription<void>? _completionSubscription;
  Completer<void>? _voiceCompletion;

  Source _source(String path) =>
      path.startsWith('/') ? DeviceFileSource(path) : AssetSource(path);

  @override
  Future<void> playVoice(String path) async {
    final completed = Completer<void>();
    _voiceCompletion = completed;
    _completionSubscription = _voice.onPlayerComplete.listen(
      (_) {
        if (!completed.isCompleted) completed.complete();
      },
      onError: (Object error) {
        if (!completed.isCompleted) completed.completeError(error);
      },
    );
    try {
      await _voice.play(_source(path));
      await completed.future;
    } finally {
      await _completionSubscription?.cancel();
      _completionSubscription = null;
      _voiceCompletion = null;
    }
  }

  @override
  Future<void> playBackground(String path, double volume) async {
    await _background.setReleaseMode(ReleaseMode.loop);
    await _background.play(_source(path), volume: volume);
  }

  @override
  Future<void> stop() async {
    final pending = _voiceCompletion;
    if (pending != null && !pending.isCompleted) pending.complete();
    await Future.wait([_voice.stop(), _background.stop()]);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await Future.wait([_voice.dispose(), _background.dispose()]);
  }
}

class ScenarioPreviewPlayer extends ChangeNotifier {
  ScenarioPreviewPlayer({PreviewAudioBackend? backend}) {
    _backend = backend;
  }

  PreviewAudioBackend? _backend;
  PreviewAudioBackend get _activeBackend =>
      _backend ??= DevicePreviewAudioBackend();
  int _generation = 0;
  Completer<void>? _reply;
  bool _closed = false;
  bool isPlaying = false;
  bool waitingForReply = false;
  String? activeStepId;
  String? error;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> start(
    Scenario scenario, {
    AmbientSound? background,
    double volume = 0.3,
  }) async {
    if (_closed) return;
    final generation = ++_generation;
    await _resetPlayback();
    if (generation != _generation || _closed) return;
    error = null;
    isPlaying = true;
    _notify();
    try {
      if (background != null) {
        await _activeBackend.playBackground(background.audioPath, volume);
      }
      for (final step in scenario.steps) {
        if (generation != _generation) break;
        activeStepId = step.id;
        waitingForReply = step.type == DialogueStepType.wait;
        _notify();
        if (step.type == DialogueStepType.wait) {
          _reply = Completer<void>();
          await _reply!.future;
          _reply = null;
        } else {
          final audioPath = step.audioPath;
          if (audioPath == null || audioPath.isEmpty) {
            throw StateError('Câu thoại này chưa có file âm thanh.');
          }
          await _activeBackend.playVoice(audioPath);
        }
      }
    } catch (_) {
      if (generation == _generation) {
        error = 'Không phát được âm thanh. Kiểm tra file và thử lại.';
      }
    } finally {
      if (generation == _generation) {
        try {
          await _backend?.stop();
        } catch (_) {
          error ??= 'Không dừng được âm thanh. Hãy thử lại.';
        }
        isPlaying = false;
        waitingForReply = false;
        activeStepId = null;
        _reply = null;
        _notify();
      }
    }
  }

  void continueAfterReply() {
    if (waitingForReply && _reply != null && !_reply!.isCompleted) {
      _reply!.complete();
    }
  }

  Future<void> stop() async {
    _generation++;
    await _resetPlayback();
  }

  Future<void> _resetPlayback() async {
    final pending = _reply;
    if (pending != null && !pending.isCompleted) pending.complete();
    _reply = null;
    isPlaying = false;
    waitingForReply = false;
    activeStepId = null;
    _notify();
    try {
      await _backend?.stop();
    } catch (_) {
      error = 'Không dừng được âm thanh. Hãy thử lại.';
      _notify();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await stop();
    await _backend?.dispose();
    super.dispose();
  }
}
