import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';

enum PhoneStyle {
  auto('Tự nhận diện'),
  iphone('iPhone'),
  samsung('Samsung'),
  xiaomi('Xiaomi'),
  huawei('Huawei');

  const PhoneStyle(this.label);
  final String label;
}

enum TriggerSensitivity {
  low('Thấp'),
  medium('Vừa'),
  high('Cao');

  const TriggerSensitivity(this.label);
  final String label;
}

@immutable
class AppSettings {
  const AppSettings({
    this.phoneStyle = PhoneStyle.auto,
    this.vibrateOnCall = true,
    this.lastDelay = AppConstants.defaultCallDelay,
    this.flipEnabled = false,
    this.sensitivity = TriggerSensitivity.medium,
    this.backgroundArmed = false,
    this.waitForReply = true,
    this.backgroundVolume = defaultBackgroundVolume,
    this.replyPause = defaultReplyPause,
    this.leaveAppAfterCall = true,
  });

  /// Người dùng im lặng bao lâu thì coi là đã nói xong và người gọi nói câu
  /// tiếp. Ngắn quá dễ cắt ngang lúc người dùng ngừng giữa câu.
  static const defaultReplyPause = Duration(seconds: 1);
  static const minReplyPause = Duration(milliseconds: 500);
  static const maxReplyPause = Duration(seconds: 5);

  /// Âm lượng âm nền trong cuộc gọi so với giọng người gọi (0–1).
  static const defaultBackgroundVolume = 0.6;
  static const minBackgroundVolume = 0.1;

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    phoneStyle: _enumByName(
      PhoneStyle.values,
      json['phoneStyle'],
      PhoneStyle.auto,
    ),
    vibrateOnCall: _bool(json['vibrateOnCall'], true),
    lastDelay: _delay(json['lastDelaySeconds']),
    flipEnabled: _bool(json['flipEnabled'], false),
    sensitivity: _enumByName(
      TriggerSensitivity.values,
      json['sensitivity'],
      TriggerSensitivity.medium,
    ),
    backgroundArmed: _bool(json['backgroundArmed'], false),
    waitForReply: _bool(json['waitForReply'], true),
    backgroundVolume: _volume(json['backgroundVolume']),
    replyPause: _replyPause(json['replyPauseMs']),
    leaveAppAfterCall: _bool(json['leaveAppAfterCall'], true),
  );

  final PhoneStyle phoneStyle;
  final bool vibrateOnCall;
  final Duration lastDelay;
  final bool flipEnabled;
  final TriggerSensitivity sensitivity;
  final bool backgroundArmed;

  /// Người gọi chờ người dùng nói xong (nghe qua micro) rồi mới nói câu tiếp.
  final bool waitForReply;

  /// Âm lượng âm nền trong cuộc gọi, dùng chung cho mọi combo.
  final double backgroundVolume;

  /// Chờ bao lâu sau khi người dùng nói xong rồi người gọi mới nói câu tiếp.
  final Duration replyPause;

  /// Cuộc gọi giả kết thúc thì về màn hình chính của điện thoại (Android),
  /// như app gọi thật tự đóng sau khi gác máy.
  final bool leaveAppAfterCall;

  Map<String, Object> toJson() => {
    'phoneStyle': phoneStyle.name,
    'vibrateOnCall': vibrateOnCall,
    'lastDelaySeconds': lastDelay.inSeconds,
    'flipEnabled': flipEnabled,
    'sensitivity': sensitivity.name,
    'backgroundArmed': backgroundArmed,
    'waitForReply': waitForReply,
    'backgroundVolume': backgroundVolume,
    'replyPauseMs': replyPause.inMilliseconds,
    'leaveAppAfterCall': leaveAppAfterCall,
  };

  AppSettings copyWith({
    PhoneStyle? phoneStyle,
    bool? vibrateOnCall,
    Duration? lastDelay,
    bool? flipEnabled,
    TriggerSensitivity? sensitivity,
    bool? backgroundArmed,
    bool? waitForReply,
    double? backgroundVolume,
    Duration? replyPause,
    bool? leaveAppAfterCall,
  }) => AppSettings(
    phoneStyle: phoneStyle ?? this.phoneStyle,
    vibrateOnCall: vibrateOnCall ?? this.vibrateOnCall,
    lastDelay: lastDelay ?? this.lastDelay,
    flipEnabled: flipEnabled ?? this.flipEnabled,
    sensitivity: sensitivity ?? this.sensitivity,
    backgroundArmed: backgroundArmed ?? this.backgroundArmed,
    waitForReply: waitForReply ?? this.waitForReply,
    backgroundVolume: backgroundVolume == null
        ? this.backgroundVolume
        : clampBackgroundVolume(backgroundVolume),
    replyPause: replyPause == null
        ? this.replyPause
        : clampReplyPause(replyPause),
    leaveAppAfterCall: leaveAppAfterCall ?? this.leaveAppAfterCall,
  );
}

/// Bước chỉnh thời gian chờ.
const replyPauseStep = Duration(milliseconds: 500);

/// Giữ thời gian chờ trong khoảng cho phép, làm tròn về bước 0,5 giây.
Duration clampReplyPause(Duration value) {
  final step = replyPauseStep.inMilliseconds;
  final snapped = Duration(
    milliseconds: (value.inMilliseconds / step).round() * step,
  );
  return snapped < AppSettings.minReplyPause
      ? AppSettings.minReplyPause
      : snapped > AppSettings.maxReplyPause
      ? AppSettings.maxReplyPause
      : snapped;
}

Duration _replyPause(Object? milliseconds) =>
    milliseconds is num && milliseconds.isFinite
    ? clampReplyPause(Duration(milliseconds: milliseconds.round()))
    : AppSettings.defaultReplyPause;

/// Giữ âm lượng nền trong khoảng nghe được, không tắt hẳn.
double clampBackgroundVolume(double value) =>
    value.clamp(AppSettings.minBackgroundVolume, 1.0).toDouble();

double _volume(Object? value) => value is num && value.isFinite
    ? clampBackgroundVolume(value.toDouble())
    : AppSettings.defaultBackgroundVolume;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

Duration _delay(Object? seconds) =>
    AppConstants.callDelays
        .where((delay) => delay.inSeconds == seconds)
        .firstOrNull ??
    AppConstants.defaultCallDelay;
