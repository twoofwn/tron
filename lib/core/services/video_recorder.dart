import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'file_service.dart';
import 'media_files.dart' as media;
import 'video_source.dart';

final videoRecorderProvider = Provider(
  (ref) => VideoRecorder(ref.watch(fileServiceProvider)),
);

/// Quay video người gọi cho cuộc gọi video và mở camera trước khi đang gọi.
/// Màn hình giữ [CameraController] để hiện khung xem trước; lớp này chỉ tạo
/// bộ điều khiển với cấu hình thống nhất và lưu bản quay thành file của app.
class VideoRecorder {
  VideoRecorder(
    this.files, {
    Future<List<CameraDescription>> Function()? listCameras,
    Future<Duration?> Function(String path)? probeDuration,
  }) : _listCameras = listCameras ?? availableCameras,
       _durationProbe = probeDuration;

  final FileService files;
  final Future<List<CameraDescription>> Function() _listCameras;
  final Future<Duration?> Function(String path)? _durationProbe;

  /// Bản quay ngắn hơn 1 giây bị coi là bấm nhầm.
  static const minDuration = Duration(seconds: 1);

  static const _videoBitrate = 1200000;
  static const _audioBitrate = 64000;

  /// Video chỉ giới hạn dung lượng ([AppConstants.maxVideoBytes]), không giới
  /// hạn độ dài. Khi quay không đọc được dung lượng file đang ghi, nên ước tính
  /// theo bitrate đã đặt.
  static int estimatedBytes(Duration elapsed) =>
      elapsed.inMilliseconds * (_videoBitrate + _audioBitrate) ~/ 8000;

  /// Tự dừng quay khi ước tính chạm 90% giới hạn: bitrate thật của máy có thể
  /// cao hơn mức đặt, chừa phần dư để bản quay không bị từ chối khi lưu.
  static const stopRatio = 0.9;

  /// Thời điểm bản quay chạm mức tự dừng (khoảng 2 phút với giới hạn 20 MB).
  static Duration get autoStopAfter => Duration(
    milliseconds:
        (AppConstants.maxVideoBytes * stopRatio * 8000) ~/
        (_videoBitrate + _audioBitrate),
  );

  /// Chỉ Android và iOS quay được video bằng camera trong app.
  static bool get canRecord =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<List<CameraDescription>> cameras() => _listCameras();

  /// Ưu tiên camera trước, giống app gọi video thật.
  static CameraDescription? preferFront(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }
    return cameras.isEmpty ? null : cameras.first;
  }

  /// Bộ điều khiển để quay video người gọi, có thu tiếng.
  CameraController recordingController(CameraDescription camera) =>
      CameraController(
        camera,
        ResolutionPreset.medium,
        videoBitrate: _videoBitrate,
        audioBitrate: _audioBitrate,
      );

  /// Camera của chính người dùng trong cuộc gọi video: chỉ xem, không thu tiếng.
  CameraController previewController(CameraDescription camera) =>
      CameraController(camera, ResolutionPreset.medium, enableAudio: false);

  /// Lưu bản quay vào thư mục của app. Trả về `media:...mp4`, hoặc `null` nếu
  /// bản quay trống. Video vượt 20 MB báo [FormatException].
  Future<String?> save(XFile recording) async {
    try {
      final bytes = await recording.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      if (bytes.length > AppConstants.maxVideoBytes) {
        throw FormatException(
          'Video nặng ${sizeLabel(bytes.length)}, vượt giới hạn '
          '${sizeLabel(AppConstants.maxVideoBytes)}. Hãy quay ngắn hơn.',
        );
      }
      return await files.storeVideo(bytes);
    } finally {
      await media.deleteTempFile(recording.path);
    }
  }

  /// Độ dài video đã lưu (`media:...mp4`), `null` nếu không đọc được.
  Future<Duration?> duration(String path) async {
    final probe = _durationProbe;
    if (probe != null) {
      return probe(path);
    }
    final controller = videoControllerFor(await files.videoLocation(path));
    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      return controller.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  /// Kiểm tra video chọn từ máy phát được. Không giới hạn độ dài: dung lượng
  /// đã được kiểm tra khi chọn file. Không đọc được thì xoá file vừa nhập và
  /// báo [FormatException].
  Future<String> checkPickedVideo(String path) async {
    final length = await duration(path);
    if (length == null || length == Duration.zero) {
      await files.deleteAudio(path);
      throw const FormatException(
        'Không đọc được video này. Hãy chọn file MP4 khác.',
      );
    }
    return path;
  }

  /// Bỏ bản quay không dùng (ví dụ quá ngắn).
  Future<void> discard(XFile recording) => media.deleteTempFile(recording.path);
}
