import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backgroundGuardProvider = Provider<BackgroundGuard>(
  (ref) => const BackgroundGuard(),
);

/// Bật/tắt dịch vụ giữ app sẵn sàng khi màn hình tắt (chỉ Android).
/// Trả về false khi không bật được; app vẫn chạy bình thường khi đang mở.
class BackgroundGuard {
  const BackgroundGuard();

  static const _channel = MethodChannel('tron/background');

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<bool> start() => _invoke('start');

  Future<bool> stop() => _invoke('stop');

  Future<bool> _invoke(String method) async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
