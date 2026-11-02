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
    this.knockEnabled = false,
    this.sensitivity = TriggerSensitivity.medium,
    this.backgroundArmed = false,
    this.waitForReply = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    phoneStyle: _enumByName(
      PhoneStyle.values,
      json['phoneStyle'],
      PhoneStyle.auto,
    ),
    vibrateOnCall: _bool(json['vibrateOnCall'], true),
    lastDelay: _delay(json['lastDelaySeconds']),
    flipEnabled: _bool(json['flipEnabled'], false),
    knockEnabled: _bool(json['knockEnabled'], false),
    sensitivity: _enumByName(
      TriggerSensitivity.values,
      json['sensitivity'],
      TriggerSensitivity.medium,
    ),
    backgroundArmed: _bool(json['backgroundArmed'], false),
    waitForReply: _bool(json['waitForReply'], true),
  );

  final PhoneStyle phoneStyle;
  final bool vibrateOnCall;
  final Duration lastDelay;
  final bool flipEnabled;
  final bool knockEnabled;
  final TriggerSensitivity sensitivity;
  final bool backgroundArmed;

  /// Người gọi chờ người dùng nói xong (nghe qua micro) rồi mới nói câu tiếp.
  final bool waitForReply;

  Map<String, Object> toJson() => {
    'phoneStyle': phoneStyle.name,
    'vibrateOnCall': vibrateOnCall,
    'lastDelaySeconds': lastDelay.inSeconds,
    'flipEnabled': flipEnabled,
    'knockEnabled': knockEnabled,
    'sensitivity': sensitivity.name,
    'backgroundArmed': backgroundArmed,
    'waitForReply': waitForReply,
  };

  AppSettings copyWith({
    PhoneStyle? phoneStyle,
    bool? vibrateOnCall,
    Duration? lastDelay,
    bool? flipEnabled,
    bool? knockEnabled,
    TriggerSensitivity? sensitivity,
    bool? backgroundArmed,
    bool? waitForReply,
  }) => AppSettings(
    phoneStyle: phoneStyle ?? this.phoneStyle,
    vibrateOnCall: vibrateOnCall ?? this.vibrateOnCall,
    lastDelay: lastDelay ?? this.lastDelay,
    flipEnabled: flipEnabled ?? this.flipEnabled,
    knockEnabled: knockEnabled ?? this.knockEnabled,
    sensitivity: sensitivity ?? this.sensitivity,
    backgroundArmed: backgroundArmed ?? this.backgroundArmed,
    waitForReply: waitForReply ?? this.waitForReply,
  );
}

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
