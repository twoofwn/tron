import '../config/app_config.dart';

abstract final class AppConstants {
  static const appName = AppConfig.appName;
  static const defaultCallDelay = AppConfig.defaultCallDelay;
  static const callDelays = AppConfig.callDelays;
  static const pagePadding = AppConfig.pagePadding;
  static const maxAudioBytes = AppConfig.maxAudioBytes;
  static const maxPackageBytes = AppConfig.maxPackageBytes;
}

String delayLabel(Duration duration) => duration.inSeconds < 60
    ? '${duration.inSeconds} giây'
    : '${duration.inMinutes} phút';
