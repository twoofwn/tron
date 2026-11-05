import '../config/app_config.dart';

abstract final class AppConstants {
  static const appName = AppConfig.appName;
  static const defaultCallDelay = AppConfig.defaultCallDelay;
  static const callDelays = AppConfig.callDelays;
  static const pagePadding = AppConfig.pagePadding;
  static const maxAudioBytes = AppConfig.maxAudioBytes;
  static const maxVideoBytes = AppConfig.maxVideoBytes;
  static const maxPackageBytes = AppConfig.maxPackageBytes;

  /// Ảnh đại diện người gọi (khớp giới hạn ảnh của server).
  static const maxAvatarBytes = 2 * 1024 * 1024;

  /// Cạnh dài nhất của ảnh đại diện sau khi thu nhỏ (điểm ảnh).
  static const avatarMaxSide = 512.0;
}

String delayLabel(Duration duration) => duration.inSeconds < 60
    ? '${duration.inSeconds} giây'
    : '${duration.inMinutes} phút';

/// Thời gian còn lại của cuộc gọi chờ: "45 giây", hoặc "14:57" khi từ 1 phút trở lên.
String countdownLabel(Duration remaining) {
  final seconds = remaining.inSeconds + 1;
  if (seconds < 60) {
    return '$seconds giây';
  }
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$rest';
}

/// Dung lượng dễ đọc theo kiểu Việt Nam: "850 KB", "10 MB", "14,2 MB".
String sizeLabel(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).ceil()} KB';
  }
  final mb = bytes / (1024 * 1024);
  final text = mb == mb.roundToDouble()
      ? mb.toStringAsFixed(0)
      : mb.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} MB';
}

/// Độ dài dễ đọc: "45 giây", hoặc "1:25" khi từ 1 phút trở lên.
String durationLabel(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 60) {
    return '$seconds giây';
  }
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
