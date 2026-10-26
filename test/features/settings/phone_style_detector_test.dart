import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/settings/services/phone_style_detector.dart';

void main() {
  test('iOS always maps to iPhone style', () {
    expect(matchPhoneStyle(isIOS: true), PhoneStyle.iphone);
  });

  test('Android manufacturers map to their call style', () {
    expect(
      matchPhoneStyle(isIOS: false, manufacturer: 'samsung'),
      PhoneStyle.samsung,
    );
    expect(
      matchPhoneStyle(isIOS: false, manufacturer: 'Redmi'),
      PhoneStyle.xiaomi,
    );
    expect(
      matchPhoneStyle(isIOS: false, manufacturer: 'HONOR'),
      PhoneStyle.huawei,
    );
  });

  test('Unknown Android manufacturer uses the Samsung-style default', () {
    expect(
      matchPhoneStyle(isIOS: false, manufacturer: 'Fairphone'),
      PhoneStyle.samsung,
    );
    expect(matchPhoneStyle(isIOS: false), PhoneStyle.samsung);
  });
}
