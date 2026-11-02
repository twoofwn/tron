import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'file_service.dart';
import 'media_files.dart' as media;

final voiceRecorderProvider = Provider((ref) {
  final recorder = VoiceRecorder(ref.watch(fileServiceProvider));
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Thu giọng người gọi thành file WAV mono rồi lưu như các âm thanh riêng khác.
class VoiceRecorder {
  VoiceRecorder(this.files, {AudioRecorder Function()? createRecorder})
    : _createRecorder = createRecorder ?? AudioRecorder.new;

  final FileService files;
  final AudioRecorder Function() _createRecorder;
  AudioRecorder? _instance;

  // Chỉ tạo bộ thu khi thật sự dùng, để không giữ micro khi chưa cần.
  AudioRecorder get _recorder => _instance ??= _createRecorder();

  /// Thu tối đa 60 giây: WAV 22 kHz mono khoảng 2,6 MB, dưới giới hạn 10 MB.
  static const maxDuration = Duration(seconds: 60);

  /// Bản thu ngắn hơn nửa giây (chỉ có phần đầu file WAV) bị coi là trống.
  static bool hasAudio(Uint8List wav) =>
      wav.length >= _wavHeaderBytes + _bytesPerSecond ~/ 2;
  static const _wavHeaderBytes = 44;
  static const _bytesPerSecond = 22050 * 2;

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 22050,
    numChannels: 1,
    noiseSuppress: true,
  );

  /// Xin quyền micro (nếu chưa có) rồi bắt đầu thu. Trả về `false` khi bị từ chối.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) {
      return false;
    }
    final path = await media.tempRecordingPath(
      'voice-${const Uuid().v4()}.wav',
    );
    await _recorder.start(_config, path: path);
    return true;
  }

  /// Dừng thu và lưu bản thu. Trả về `media:...wav`, hoặc `null` nếu không có gì.
  Future<String?> stop() async {
    final bytes = await stopBytes();
    return bytes == null ? null : files.storeAudio(bytes, 'wav');
  }

  /// Dừng thu, trả về dữ liệu WAV để nơi gọi tự lưu (ví dụ câu thoại của kịch
  /// bản), hoặc `null` nếu bản thu trống. Xoá file tạm.
  Future<Uint8List?> stopBytes() async {
    final output = await _recorder.stop();
    if (output == null || output.isEmpty) {
      return null;
    }
    try {
      final bytes = await XFile(output).readAsBytes();
      return hasAudio(bytes) ? bytes : null;
    } finally {
      await media.deleteTempFile(output);
    }
  }

  /// Bỏ bản đang thu, không lưu gì.
  Future<void> cancel() => _recorder.cancel();

  void dispose() {
    _instance?.dispose();
    _instance = null;
  }
}
