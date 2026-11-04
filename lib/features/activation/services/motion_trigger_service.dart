import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../settings/models/app_settings.dart';
import 'gesture_detectors.dart';

final motionTriggerServiceProvider = Provider<MotionTriggerService>((ref) {
  final service = MotionTriggerService();
  ref.onDispose(service.dispose);
  return service;
});

/// Đọc cảm biến và phát ra các cử chỉ. Chỉ chạy khi app đang mở.
class MotionTriggerService {
  MotionTriggerService({
    Stream<AccelerometerEvent> Function()? gravity,
    DateTime Function()? clock,
  }) : _gravity = gravity ?? _defaultGravity,
       _clock = clock ?? DateTime.now;

  // Chỉ mở cảm biến khi thật sự bật cử chỉ (xem start); tạo sớm sẽ gọi plugin ngay.
  static Stream<AccelerometerEvent> _defaultGravity() =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);

  final Stream<AccelerometerEvent> Function() _gravity;
  final DateTime Function() _clock;
  final _triggers = StreamController<TriggerEvent>.broadcast();
  StreamSubscription<AccelerometerEvent>? _gravitySub;

  Stream<TriggerEvent> get triggers => _triggers.stream;

  void start({required bool flip, required TriggerSensitivity sensitivity}) {
    stop();
    final tuning = GestureTuning.of(sensitivity);
    if (flip) {
      final detector = FlipDetector(faceDownZ: tuning.faceDownZ);
      _gravitySub = _gravity().listen(
        (event) {
          final now = _clock();
          if (detector.add(now, event.z)) {
            _triggers.add(TriggerEvent(TriggerKind.flip, now));
          }
        },
        // Máy không có cảm biến hoặc bị từ chối: bỏ qua, không làm app dừng.
        onError: (_) {},
      );
    }
  }

  void stop() {
    _gravitySub?.cancel();
    _gravitySub = null;
  }

  void dispose() {
    stop();
    _triggers.close();
  }
}
