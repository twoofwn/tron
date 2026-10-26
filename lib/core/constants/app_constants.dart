abstract final class AppConstants {
  static const appName = 'TRỐN';
  static const defaultCallDelay = Duration(seconds: 30);
  static const callDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];
  static const pagePadding = 22.0;
  static const maxAudioBytes = 10 * 1024 * 1024;
  static const maxPackageBytes = 25 * 1024 * 1024;
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
