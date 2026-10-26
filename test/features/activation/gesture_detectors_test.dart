import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/activation/services/gesture_detectors.dart';

void main() {
  final start = DateTime(2026, 10, 26, 9);
  DateTime at(int ms) => start.add(Duration(milliseconds: ms));

  group('FlipDetector', () {
    test('a phone turned face-down after being face-up triggers once', () {
      final detector = FlipDetector(faceDownZ: -8.5);
      final results = <bool>[];
      // Ngửa 500 ms, sau đó úp 1,5 giây (mỗi mẫu cách 100 ms).
      for (var ms = 0; ms <= 500; ms += 100) {
        results.add(detector.add(at(ms), 9.8));
      }
      for (var ms = 600; ms <= 2100; ms += 100) {
        results.add(detector.add(at(ms), -9.8));
      }
      expect(results.where((fired) => fired).length, 1);
    });

    test('a phone that starts face-down does not trigger', () {
      final detector = FlipDetector(faceDownZ: -8.5);
      final fired = [
        for (var ms = 0; ms <= 3000; ms += 100) detector.add(at(ms), -9.8),
      ];
      expect(fired.any((value) => value), isFalse);
    });

    test('a brief face-down moment shorter than the hold does not trigger', () {
      final detector = FlipDetector(faceDownZ: -8.5);
      detector.add(at(0), 9.8);
      final fired = [
        for (var ms = 100; ms <= 600; ms += 100) detector.add(at(ms), -9.8),
      ];
      expect(fired.any((value) => value), isFalse);
    });

    test('it must face up again before triggering a second time', () {
      final detector = FlipDetector(faceDownZ: -8.5);
      detector.add(at(0), 9.8);
      expect(
        [for (var ms = 100; ms <= 1200; ms += 100) detector.add(at(ms), -9.8)]
            .where((value) => value)
            .length,
        1,
      );
      // Vẫn úp tiếp, không được kích hoạt lại.
      expect(
        [for (var ms = 1300; ms <= 3000; ms += 100) detector.add(at(ms), -9.8)]
            .any((value) => value),
        isFalse,
      );
      detector.add(at(3100), 9.8);
      expect(detector.add(at(3200), -9.8), isFalse);
      expect(detector.add(at(4300), -9.8), isTrue);
    });
  });

  group('KnockDetector', () {
    KnockDetector detector() => KnockDetector(peak: 4.5);

    test('two taps about 300 ms apart trigger once', () {
      final knock = detector();
      expect(knock.add(at(0), 8), isFalse);
      expect(knock.add(at(300), 8), isTrue);
    });

    test('a single tap does not trigger', () {
      final knock = detector();
      expect(knock.add(at(0), 8), isFalse);
      expect(knock.add(at(20), 2), isFalse);
    });

    test('taps further apart than the window do not trigger', () {
      final knock = detector();
      knock.add(at(0), 8);
      expect(knock.add(at(900), 8), isFalse);
    });

    test('samples from one physical tap are merged into one peak', () {
      final knock = detector();
      // Ba mẫu cách nhau 20 ms là một cú gõ, không được tính là hai.
      expect(knock.add(at(0), 8), isFalse);
      expect(knock.add(at(20), 8), isFalse);
      expect(knock.add(at(40), 8), isFalse);
      expect(knock.add(at(300), 8), isTrue);
    });

    test('rapid repeated peaks from shaking the phone are ignored', () {
      final knock = detector();
      final fired = [for (var i = 0; i < 6; i++) knock.add(at(i * 100), 8)];
      expect(fired.any((value) => value), isFalse);
    });

    test(
      'a second double-tap right after a trigger is blocked by cooldown',
      () {
        final knock = detector();
        knock.add(at(0), 8);
        expect(knock.add(at(300), 8), isTrue);
        knock.add(at(700), 8);
        expect(knock.add(at(900), 8), isFalse);
      },
    );
  });
}
