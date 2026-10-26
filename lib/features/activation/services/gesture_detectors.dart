import 'package:flutter/foundation.dart';

import '../../settings/models/app_settings.dart';

/// Ngưỡng theo độ nhạy. Giá trị ước lượng, cần chỉnh lại trên máy thật.
@immutable
class GestureTuning {
  const GestureTuning({required this.faceDownZ, required this.knockPeak});

  /// Gia tốc trục z (m/s²) khi máy úp; càng âm càng phải úp hẳn.
  final double faceDownZ;

  /// Độ lớn gia tốc tuyến tính (m/s²) để tính là một lần gõ.
  final double knockPeak;

  static GestureTuning of(TriggerSensitivity sensitivity) =>
      switch (sensitivity) {
        TriggerSensitivity.low => const GestureTuning(
          faceDownZ: -9.3,
          knockPeak: 6,
        ),
        TriggerSensitivity.medium => const GestureTuning(
          faceDownZ: -8.5,
          knockPeak: 4.5,
        ),
        TriggerSensitivity.high => const GestureTuning(
          faceDownZ: -7.5,
          knockPeak: 3.5,
        ),
      };
}

enum TriggerKind { flip, knock }

@immutable
class TriggerEvent {
  const TriggerEvent(this.kind, this.at);

  final TriggerKind kind;
  final DateTime at;
}

/// Lật máy: máy phải ngửa trước, sau đó úp đủ lâu. Máy đã úp sẵn thì không kích hoạt.
class FlipDetector {
  FlipDetector({
    required this.faceDownZ,
    this.hold = const Duration(seconds: 1),
  });

  static const _faceUpZ = 6.0;

  final double faceDownZ;
  final Duration hold;
  bool _armed = false;
  DateTime? _downSince;

  /// Trả về true đúng một lần khi máy vừa úp đủ lâu; muốn lần sau phải ngửa lại.
  bool add(DateTime at, double z) {
    if (z >= _faceUpZ) {
      _armed = true;
      _downSince = null;
      return false;
    }
    if (z > faceDownZ) {
      _downSince = null;
      return false;
    }
    if (!_armed) {
      return false;
    }
    _downSince ??= at;
    if (at.difference(_downSince!) < hold) {
      return false;
    }
    _armed = false;
    _downSince = null;
    return true;
  }
}

/// Gõ lưng hai lần: hai đỉnh gia tốc cách nhau 150–500 ms.
class KnockDetector {
  KnockDetector({
    required this.peak,
    this.minGap = const Duration(milliseconds: 150),
    this.maxGap = const Duration(milliseconds: 500),
    this.refractory = const Duration(milliseconds: 80),
    this.cooldown = const Duration(seconds: 2),
  });

  static const _burstWindow = Duration(seconds: 2);
  static const _maxBurst = 4;

  final double peak;
  final Duration minGap;
  final Duration maxGap;

  /// Một cú gõ kéo theo nhiều mẫu liên tiếp; khoảng này được gộp lại thành một đỉnh.
  final Duration refractory;
  final Duration cooldown;

  final List<DateTime> _peaks = [];
  DateTime? _lastPeak;
  DateTime? _lastTrigger;

  /// [magnitude] là độ lớn gia tốc tuyến tính, không tính trọng lực.
  bool add(DateTime at, double magnitude) {
    final lastTrigger = _lastTrigger;
    if (lastTrigger != null && at.difference(lastTrigger) < cooldown) {
      return false;
    }
    if (magnitude < peak) {
      return false;
    }
    final lastPeak = _lastPeak;
    if (lastPeak != null && at.difference(lastPeak) < refractory) {
      return false;
    }
    _lastPeak = at;
    _peaks
      ..removeWhere((time) => at.difference(time) > _burstWindow)
      ..add(at);
    // Nhiều đỉnh dồn dập là đang di chuyển hoặc lắc máy, không phải gõ.
    if (_peaks.length > _maxBurst) {
      _peaks.clear();
      return false;
    }
    if (_peaks.length < 2) {
      return false;
    }
    final gap = at.difference(_peaks[_peaks.length - 2]);
    if (gap < minGap || gap > maxGap) {
      return false;
    }
    _peaks.clear();
    _lastTrigger = at;
    return true;
  }
}
