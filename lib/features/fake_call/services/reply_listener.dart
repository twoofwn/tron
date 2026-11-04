import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'turn_detector.dart';

/// Dùng chung cho cả app; màn gọi đóng micro khi cuộc gọi kết thúc.
final replyListenerProvider = Provider<ReplyListener>((ref) {
  final listener = MicReplyListener();
  ref.onDispose(listener.dispose);
  return listener;
});

/// Nghe người dùng trả lời trong cuộc gọi giả để người gọi nói đúng lượt.
abstract class ReplyListener {
  /// Đang trong lượt chờ người dùng nói (để màn xem thử hiện chỉ báo).
  ValueListenable<bool> get listening;

  /// Máy này nghe được người dùng qua micro trong cuộc gọi giả.
  bool get isSupported;

  /// Đã có quyền micro. [request] thì hỏi người dùng nếu chưa có.
  Future<bool> hasPermission({bool request = false});

  /// Mở micro. Trả về `false` khi không có quyền hoặc máy không thu được.
  /// [askPermission] chỉ dùng ở bản xem thử: cuộc gọi thật không hiện hộp thoại.
  Future<bool> open({bool askPermission = false});

  /// Chờ người dùng nói xong. Micro chưa mở thì chờ đúng [fallback].
  Future<ReplyOutcome> waitForReply(Duration fallback);

  /// Đóng micro, bỏ lượt chờ đang chạy.
  Future<void> close();

  void dispose();
}

/// Đọc micro dạng luồng PCM, chỉ đo độ lớn trong bộ nhớ: không lưu file,
/// không gửi đi đâu. Chỉ Android: iOS chưa chuyển âm thanh sang chế độ cuộc
/// gọi nên mở micro có thể đổi loa phát.
class MicReplyListener implements ReplyListener {
  MicReplyListener({
    AudioRecorder Function()? createRecorder,
    this.rules = const TurnRules(),
    bool? supported,
  }) : _createRecorder = createRecorder ?? AudioRecorder.new,
       _supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       _detector = TurnDetector(rules: rules);

  final AudioRecorder Function() _createRecorder;
  final TurnRules rules;
  final bool _supported;
  final TurnDetector _detector;
  final _meter = PcmLevelMeter(sampleRate: _sampleRate);
  final _listening = ValueNotifier(false);
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _subscription;
  Completer<ReplyOutcome>? _wait;
  Timer? _guard;
  bool _disposed = false;
  // Tăng mỗi lần đóng, để lần mở đang dở biết là phải hủy.
  int _session = 0;

  static const _sampleRate = 16000;

  /// Không dùng nguồn thu kiểu cuộc gọi (`voiceCommunication`) và không khử
  /// ồn: hai thứ đó bật bộ lọc giọng nói của máy, bộ lọc này cắt luôn âm nền
  /// người gọi (xe cộ, mưa) trong lúc chờ người dùng đáp. Vẫn khử vọng để
  /// giọng người gọi lọt vào micro không bị tính là người dùng nói. Không để
  /// thư viện đổi chế độ loa, giành quyền phát hay bật tai nghe Bluetooth:
  /// màn gọi đã tự lo những việc đó.
  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: _sampleRate,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: false,
    audioInterruption: AudioInterruptionMode.none,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.voiceRecognition,
      manageBluetooth: false,
    ),
  );

  @override
  ValueListenable<bool> get listening => _listening;

  bool get isOpen => _subscription != null;

  @override
  bool get isSupported => _supported;

  @override
  Future<bool> hasPermission({bool request = false}) async {
    if (!_supported || _disposed) {
      return false;
    }
    try {
      return await (_recorder ??= _createRecorder()).hasPermission(
        request: request,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> open({bool askPermission = false}) async {
    if (_subscription != null) {
      return true;
    }
    final session = _session;
    if (!await hasPermission(request: askPermission) || session != _session) {
      return false;
    }
    try {
      final recorder = _recorder ??= _createRecorder();
      final stream = await recorder.startStream(_config);
      // Cuộc gọi kết thúc trong lúc đang mở micro: đóng ngay.
      if (_disposed || session != _session) {
        await recorder.stop();
        return false;
      }
      _meter.reset();
      _subscription = stream.listen(
        _onAudio,
        onError: (Object _) => _lostMic(),
        onDone: _lostMic,
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ReplyOutcome> waitForReply(Duration fallback) async {
    _finish(ReplyOutcome.cancelled);
    if (_subscription == null) {
      await Future<void>.delayed(fallback);
      return ReplyOutcome.noReply;
    }
    _detector.reset();
    final wait = _wait = Completer<ReplyOutcome>();
    _listening.value = true;
    // Micro ngừng gửi dữ liệu thì không để cuộc gọi đứng mãi.
    _guard = Timer(rules.noReply + const Duration(seconds: 1), () {
      if (!_detector.heardSpeech) {
        _finish(ReplyOutcome.noReply);
        return;
      }
      _guard = Timer(rules.maxReply, () => _finish(ReplyOutcome.tooLong));
    });
    return wait.future;
  }

  void _onAudio(Uint8List chunk) {
    final levels = _meter.add(chunk);
    if (_wait == null) {
      return;
    }
    for (final level in levels) {
      final outcome = _detector.addLevel(level, _meter.frameLength);
      if (outcome != null) {
        _finish(outcome);
        return;
      }
    }
  }

  /// Micro bị app khác chiếm hoặc lỗi: lượt đang chờ kết thúc, các lượt sau
  /// chờ theo thời gian cố định.
  void _lostMic() {
    _subscription = null;
    _finish(ReplyOutcome.noReply);
  }

  void _finish(ReplyOutcome outcome) {
    _guard?.cancel();
    _guard = null;
    final wait = _wait;
    _wait = null;
    if (!_disposed) {
      _listening.value = false;
    }
    if (wait != null && !wait.isCompleted) {
      wait.complete(outcome);
    }
  }

  @override
  Future<void> close() async {
    _session++;
    _finish(ReplyOutcome.cancelled);
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel();
      await _recorder?.stop();
    } catch (_) {
      // Micro đã đóng sẵn.
    }
  }

  @override
  void dispose() {
    unawaited(close());
    _disposed = true;
    _listening.dispose();
    unawaited(_recorder?.dispose().catchError((Object _) {}));
    _recorder = null;
  }
}
