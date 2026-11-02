import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final callDeviceServiceProvider = Provider<CallDeviceService>((ref) {
  final service = CallDeviceService();
  ref.onDispose(service.dispose);
  return service;
});

/// Phần cuộc gọi cần code Android (`MainActivity.kt`): phím âm lượng và
/// loa trong / loa ngoài. Nền tảng chưa hỗ trợ thì mọi lệnh bỏ qua lặng lẽ.
class CallDeviceService {
  CallDeviceService([this._channel = const MethodChannel('tron/call')]) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeKey') {
        _volumeKeys.add(null);
      }
    });
  }

  final MethodChannel _channel;
  final _volumeKeys = StreamController<void>.broadcast();

  /// Người dùng bấm phím âm lượng trong lúc [setSilenceKeys] đang bật.
  Stream<void> get volumeKeyPresses => _volumeKeys.stream;

  /// Bật: phím âm lượng tắt chuông và không đổi âm lượng máy.
  Future<void> setSilenceKeys(bool enabled) =>
      _invoke('setSilenceKeys', enabled);

  /// Chuyển máy sang chế độ cuộc gọi, phát ra loa trong trừ khi [speaker].
  Future<void> startCallAudio({required bool speaker}) =>
      _invoke('startCallAudio', speaker);

  Future<void> setSpeaker(bool on) => _invoke('setSpeaker', on);

  /// Trả âm thanh của máy về bình thường sau cuộc gọi.
  Future<void> endCallAudio() => _invoke('endCallAudio');

  Future<void> _invoke(String method, [Object? argument]) async {
    try {
      await _channel.invokeMethod<void>(method, argument);
    } on MissingPluginException {
      // iOS, web, test: chưa có code nền tảng.
    } on PlatformException {
      // Máy từ chối đổi đường âm thanh: cuộc gọi vẫn tiếp tục ở loa hiện tại.
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_volumeKeys.close());
  }
}
