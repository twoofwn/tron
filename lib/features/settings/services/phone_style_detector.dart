import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';

/// Tách khỏi plugin để test được logic so khớp hãng máy.
PhoneStyle matchPhoneStyle({required bool isIOS, String? manufacturer}) {
  if (isIOS) {
    return PhoneStyle.iphone;
  }
  final maker = (manufacturer ?? '').toLowerCase();
  if (maker.contains('samsung')) {
    return PhoneStyle.samsung;
  }
  if (maker.contains('xiaomi') ||
      maker.contains('redmi') ||
      maker.contains('poco')) {
    return PhoneStyle.xiaomi;
  }
  if (maker.contains('huawei') || maker.contains('honor')) {
    return PhoneStyle.huawei;
  }
  // Android không rõ hãng: dùng mẫu phổ biến nhất trên Android.
  return PhoneStyle.samsung;
}

Future<PhoneStyle> detectDevicePhoneStyle() async {
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return matchPhoneStyle(isIOS: true);
      case TargetPlatform.android:
        final info = await DeviceInfoPlugin().androidInfo;
        return matchPhoneStyle(isIOS: false, manufacturer: info.manufacturer);
      default:
        return PhoneStyle.iphone;
    }
  } catch (_) {
    return PhoneStyle.iphone;
  }
}
