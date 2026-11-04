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
}
