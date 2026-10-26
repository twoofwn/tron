import 'package:flutter/foundation.dart';

/// Cấu hình mặc định cho toàn bộ ứng dụng TRỐN (EscapeHatch).
/// Cho phép ghi đè linh hoạt qua `--dart-define` khi build hoặc chạy.
/// Ví dụ:
///   flutter run --dart-define=API_BASE_URL=https://api.mytron.com
abstract final class AppConfig {
  // ==========================================
  // 1. CẤU HÌNH MẠNG & API
  // ==========================================
  static const String defaultProductionApiBaseUrl =
      'https://hadps1612-001-site1.ltempurl.com';

  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return defined.replaceAll(RegExp(r'/+$'), '');
    if (kReleaseMode) {
      return defaultProductionApiBaseUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:5080';
      }
      return 'http://localhost:5080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5080';
    }
    return 'http://localhost:5080';
  }

  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 30,
  );

  static Duration get apiTimeout => const Duration(seconds: apiTimeoutSeconds);

  static const String apiVersionPrefix = '/api/v1';

  // ==========================================
  // 2. GIỚI HẠN TẬP TIN & DUNG LƯỢNG
  // ==========================================
  static const int maxAudioBytes = int.fromEnvironment(
    'MAX_AUDIO_BYTES',
    defaultValue: 10 * 1024 * 1024, // 10 MB
  );

  static const int maxPackageBytes = int.fromEnvironment(
    'MAX_PACKAGE_BYTES',
    defaultValue: 25 * 1024 * 1024, // 25 MB
  );

  static const int defaultQuotaMediaBytes = int.fromEnvironment(
    'DEFAULT_QUOTA_MEDIA_BYTES',
    defaultValue: 200 * 1024 * 1024, // 200 MB
  );

  // ==========================================
  // 3. THÔNG TIN ỨNG DỤNG & METADATA
  // ==========================================
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'TRỐN',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String shareCodePrefix = 'EH-';

  // ==========================================
  // 4. CẤU HÌNH MẶC ĐỊNH CUỘC GỌI & GIAO DIỆN
  // ==========================================
  static const Duration defaultCallDelay = Duration(seconds: 30);

  static const List<Duration> callDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  static const double defaultBackgroundVolume = 0.5;
  static const String defaultRingtoneId = 'marimba';
  static const double pagePadding = 22.0;

  // ==========================================
  // 5. CÁC KHÓA LƯU TRỮ CỤC BỘ (STORAGE KEYS)
  // ==========================================
  static const String accessTokenKey = 'tron.auth.accessToken';
  static const String refreshTokenKey = 'tron.auth.refreshToken';
  static const String userKey = 'tron.auth.user';
  static const String combosKey = 'tron.combos.v1';
  static const String emergencyKey = 'tron.emergency';
  static const String themeKey = 'tron.theme';
  static const String userScenariosKey = 'tron.scenarios.user.v1';
  static const String backgroundsKey = 'tron.scenarios.backgrounds.v1';
}
