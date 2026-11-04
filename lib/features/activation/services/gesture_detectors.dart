import 'package:flutter/foundation.dart';

import '../../settings/models/app_settings.dart';

/// Ngưỡng theo độ nhạy. Giá trị ước lượng, cần chỉnh lại trên máy thật.
@immutable
class GestureTuning {
  const GestureTuning({required this.faceDownZ});

  /// Gia tốc trục z (m/s²) khi máy úp; càng âm càng phải úp hẳn.
  final double faceDownZ;

  static GestureTuning of(TriggerSensitivity sensitivity) =>
      switch (sensitivity) {
        TriggerSensitivity.low => const GestureTuning(faceDownZ: -9.3),
        TriggerSensitivity.medium => const GestureTuning(faceDownZ: -8.5),
        TriggerSensitivity.high => const GestureTuning(faceDownZ: -7.5),
      };
}

enum TriggerKind { flip }

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
