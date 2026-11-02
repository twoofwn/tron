import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/constants/built_in_ringtone.dart';
import 'package:tron/features/activation/services/call_alarm_service.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/shared/enums/call_interface.dart';

void main() {
  BuiltInRingtone resolve(
    CallInterface callInterface,
    PhoneStyle phoneStyle, {
    RingtoneType type = RingtoneType.interfaceDefault,
  }) => BuiltInRingtone.resolve(
    type: type,
    callInterface: callInterface,
    phoneStyle: phoneStyle,
  );

  test('Phone interface rings with the chosen phone style', () {
    expect(
      resolve(CallInterface.phone, PhoneStyle.iphone),
      BuiltInRingtone.iphone,
    );
    expect(
      resolve(CallInterface.phone, PhoneStyle.samsung),
      BuiltInRingtone.samsung,
    );
    expect(
      resolve(CallInterface.phone, PhoneStyle.huawei),
      BuiltInRingtone.huawei,
    );
    // Không có chuông Xiaomi: dùng chuông Samsung.
    expect(
      resolve(CallInterface.phone, PhoneStyle.xiaomi),
      BuiltInRingtone.samsung,
    );
    expect(
      resolve(CallInterface.phone, PhoneStyle.auto),
      BuiltInRingtone.samsung,
    );
  });

  test('Zalo and Messenger ignore the phone style', () {
    for (final style in PhoneStyle.values) {
      expect(resolve(CallInterface.zalo, style), BuiltInRingtone.zalo);
      expect(
        resolve(CallInterface.messenger, style),
        BuiltInRingtone.messenger,
      );
    }
  });

  test(
    'Classic wins and a custom file falls back to the interface ringtone',
    () {
      expect(
        resolve(
          CallInterface.zalo,
          PhoneStyle.iphone,
          type: RingtoneType.classic,
        ),
        BuiltInRingtone.classic,
      );
      expect(
        resolve(
          CallInterface.messenger,
          PhoneStyle.iphone,
          type: RingtoneType.custom,
        ),
        BuiltInRingtone.messenger,
      );
    },
  );

  test('Every ringtone ships as a Flutter asset and an Android resource', () {
    for (final ringtone in BuiltInRingtone.values) {
      expect(File(ringtone.asset).existsSync(), isTrue, reason: ringtone.asset);
      final raw = Directory('android/app/src/main/res/raw')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.split('.').first == ringtone.androidResource);
      expect(raw, hasLength(1), reason: ringtone.androidResource);
    }
  });

  test('Each ringtone has its own channel ringing on the ringer volume', () {
    final ids = {
      for (final ringtone in BuiltInRingtone.values) ringtone.channelId,
    };
    expect(ids, hasLength(BuiltInRingtone.values.length));
    final channel = CallAlarmService.channelFor(BuiltInRingtone.iphone);
    expect(channel.importance, Importance.max);
    expect(channel.sound?.sound, 'ring_iphone');
    expect(
      channel.audioAttributesUsage,
      AudioAttributesUsage.notificationRingtone,
    );
  });

  test('The call notification repeats and stops after the timeout', () {
    final details = CallAlarmService.androidDetailsFor(BuiltInRingtone.zalo);
    expect(details.channelId, BuiltInRingtone.zalo.channelId);
    expect(details.sound?.sound, 'ring_zalo');
    expect(details.fullScreenIntent, isTrue);
    // 4 là FLAG_INSISTENT: chuông kêu lặp tới khi thông báo bị hủy.
    expect(details.additionalFlags, contains(4));
    expect(details.timeoutAfter, CallAlarmService.ringTimeout.inMilliseconds);
  });
}
