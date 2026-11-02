import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'file_service.dart';
import 'media_files.dart' as media;

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
  }) : _listCameras = listCameras ?? availableCameras;

  final FileService files;
  final Future<List<CameraDescription>> Function() _listCameras;

  /// Quay tối đa 60 giây: khoảng 1,3 Mbps nên dưới 10 MB, trong giới hạn 20 MB.
  static const maxDuration = Duration(seconds: 60);

  /// Bản quay ngắn hơn 1 giây bị coi là bấm nhầm.
  static const minDuration = Duration(seconds: 1);

  static const _videoBitrate = 1200000;
  static const _audioBitrate = 64000;

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
        throw const FormatException('Video vượt 20 MB. Hãy quay ngắn hơn.');
      }
      return await files.storeVideo(bytes);
    } finally {
      await media.deleteTempFile(recording.path);
    }
  }

  /// Bỏ bản quay không dùng (ví dụ quá ngắn).
  Future<void> discard(XFile recording) => media.deleteTempFile(recording.path);
}
