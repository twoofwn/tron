import '../config/app_config.dart';

abstract final class AppConstants {
  static const appName = AppConfig.appName;
  static const defaultCallDelay = AppConfig.defaultCallDelay;
  static const callDelays = AppConfig.callDelays;
  static const pagePadding = AppConfig.pagePadding;
  static const maxAudioBytes = AppConfig.maxAudioBytes;
  static const maxVideoBytes = AppConfig.maxVideoBytes;
  static const maxPackageBytes = AppConfig.maxPackageBytes;
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
