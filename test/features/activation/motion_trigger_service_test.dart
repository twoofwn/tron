import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tron/features/activation/services/gesture_detectors.dart';
import 'package:tron/features/activation/services/motion_trigger_service.dart';
import 'package:tron/features/settings/models/app_settings.dart';

void main() {
  late StreamController<AccelerometerEvent> gravity;
  late StreamController<UserAccelerometerEvent> linear;
  late DateTime now;
  late MotionTriggerService service;
  final received = <TriggerEvent>[];
  late StreamSubscription<TriggerEvent> subscription;

  setUp(() {
    gravity = StreamController<AccelerometerEvent>.broadcast();
    linear = StreamController<UserAccelerometerEvent>.broadcast();
    now = DateTime(2026, 10, 26, 9);
    service = MotionTriggerService(
      gravity: () => gravity.stream,
      linear: () => linear.stream,
      clock: () => now,
    );
    received.clear();
    subscription = service.triggers.listen(received.add);
  });

  tearDown(() async {
    await subscription.cancel();
    service.dispose();
    await gravity.close();
    await linear.close();
  });

  // Stream phát sự kiện bất đồng bộ: chờ sau mỗi mẫu để đồng hồ khớp từng mẫu.
  Future<void> feedGravity(double z, Duration step) async {
    now = now.add(step);
    gravity.add(AccelerometerEvent(0, 0, z, now));
    await Future<void>.delayed(Duration.zero);
  }

  test('flipping face-down emits one flip event', () async {
    service.start(
      flip: true,
      knock: false,
      sensitivity: TriggerSensitivity.medium,
    );
    for (var i = 0; i < 5; i++) {
      await feedGravity(9.8, const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 15; i++) {
      await feedGravity(-9.8, const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(Duration.zero);
    expect(received.map((event) => event.kind), [TriggerKind.flip]);
  });

  test('flip events are ignored when flip is turned off', () async {
    service.start(
      flip: false,
      knock: false,
      sensitivity: TriggerSensitivity.medium,
    );
    for (var i = 0; i < 5; i++) {
      await feedGravity(9.8, const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 15; i++) {
      await feedGravity(-9.8, const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
  });

  test('stop cancels detection', () async {
    service.start(
      flip: true,
      knock: false,
      sensitivity: TriggerSensitivity.medium,
    );
    service.stop();
    for (var i = 0; i < 5; i++) {
      await feedGravity(9.8, const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 15; i++) {
      await feedGravity(-9.8, const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
  });

  test('two strong taps emit a knock event', () async {
    service.start(
      flip: false,
      knock: true,
      sensitivity: TriggerSensitivity.medium,
    );
    now = now.add(const Duration(milliseconds: 100));
    linear.add(UserAccelerometerEvent(0, 0, 8, now));
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(milliseconds: 300));
    linear.add(UserAccelerometerEvent(0, 0, 8, now));
    await Future<void>.delayed(Duration.zero);
    expect(received.map((event) => event.kind), [TriggerKind.knock]);
  });
}
