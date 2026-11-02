import '../../features/settings/models/app_settings.dart';
import '../../shared/enums/call_interface.dart';

/// Chuông có sẵn trong app. Mỗi chuông có hai bản giống nhau: [asset] để app
/// phát khi đang mở, [androidResource] (trong `android/app/src/main/res/raw`)
/// để thông báo hệ thống phát khi máy khóa.
enum BuiltInRingtone {
  iphone('assets/audio/ringtones/iphone.mp3', 'ring_iphone', 'Chuông iPhone'),
  samsung(
    'assets/audio/ringtones/samsung.mp3',
    'ring_samsung',
    'Chuông Samsung',
  ),
  huawei('assets/audio/ringtones/huawei.mp3', 'ring_huawei', 'Chuông Huawei'),
  zalo('assets/audio/ringtones/zalo.mp3', 'ring_zalo', 'Chuông Zalo'),
  messenger(
    'assets/audio/ringtones/messenger.mp3',
    'ring_messenger',
    'Chuông Messenger',
  ),
  classic(
    'assets/audio/ringtones/classic_ring.wav',
    'ring_classic',
    'Chuông cổ điển',
  );

  const BuiltInRingtone(this.asset, this.androidResource, this.label);

  final String asset;
  final String androidResource;
  final String label;

  /// Từ Android 8, âm thanh gắn cố định vào kênh thông báo nên mỗi chuông
  /// cần một kênh riêng.
  String get channelId => 'incoming_calls_$name';

  /// Chuông có sẵn cho combo. Chuông cá nhân không phát được qua thông báo
  /// hệ thống, nên khi đó dùng chuông theo giao diện.
  static BuiltInRingtone resolve({
    required RingtoneType type,
    required CallInterface callInterface,
    required PhoneStyle phoneStyle,
  }) {
    if (type == RingtoneType.classic) {
      return classic;
    }
    return switch (callInterface) {
      CallInterface.zalo => zalo,
      CallInterface.messenger => messenger,
      CallInterface.phone => switch (phoneStyle) {
        PhoneStyle.iphone => iphone,
        PhoneStyle.huawei => huawei,
        // Không có chuông Xiaomi; máy chưa rõ hãng cũng dùng kiểu Samsung.
        PhoneStyle.samsung || PhoneStyle.xiaomi || PhoneStyle.auto => samsung,
      },
    };
  }
}
