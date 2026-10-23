abstract final class AppConstants {
  static const appName = 'TRỐN';
  static const defaultCallDelay = Duration(seconds: 30);
  static const callDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];
  static const pagePadding = 22.0;
  static const maxAudioBytes = 10 * 1024 * 1024;
  static const maxPackageBytes = 25 * 1024 * 1024;
}

String delayLabel(Duration duration) => duration.inSeconds < 60
    ? '${duration.inSeconds} giây'
    : '${duration.inMinutes} phút';
