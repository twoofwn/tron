import 'package:flutter/foundation.dart';

/// Vị trí lấy được lúc gửi SOS.
@immutable
class SosLocation {
  const SosLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;

  /// Bán kính sai số (mét), nếu máy cho biết.
  final double? accuracy;

  /// Link mở được trên mọi điện thoại, không cần API key.
  String get mapsLink =>
      'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},'
      '${longitude.toStringAsFixed(6)}';
}

/// Chỗ trống người dùng chèn được vào mẫu tin nhắn.
enum SosPlaceholder {
  location('{vitri}', 'Vị trí'),
  time('{thoigian}', 'Giờ gửi'),
  battery('{pin}', 'Pin');

  const SosPlaceholder(this.token, this.label);
  final String token;
  final String label;
}

/// Số tin SMS mà một nội dung sẽ bị tách thành.
@immutable
class SmsSize {
  const SmsSize({
    required this.characters,
    required this.parts,
    required this.unicode,
  });

  final int characters;
  final int parts;

  /// Có dấu tiếng Việt (hoặc ký tự đặc biệt): mỗi tin chỉ chứa khoảng 70 ký tự.
  final bool unicode;
}

/// Soạn nội dung SOS. Bản Android chạy nền (`SosTools.render` trong Kotlin)
/// phải cho ra cùng kết quả.
abstract final class SosMessage {
  static const noLocation = '(không lấy được vị trí)';

  static const _sampleLocation = SosLocation(
    latitude: 21.028511,
    longitude: 105.804817,
  );

  static String render(
    String template, {
    required SosLocation? location,
    required DateTime now,
    int? battery,
    bool plain = false,
  }) {
    final text = template
        .replaceAll(
          SosPlaceholder.location.token,
          location?.mapsLink ?? noLocation,
        )
        .replaceAll(SosPlaceholder.time.token, formatTime(now))
        .replaceAll(
          SosPlaceholder.battery.token,
          battery == null ? '?' : '$battery%',
        )
        .trim();
    return plain ? stripDiacritics(text) : text;
  }

  /// Bản xem trước với vị trí mẫu, để người dùng thấy tin sẽ dài bao nhiêu.
  static String preview(String template, {bool plain = false, DateTime? now}) =>
      render(
        template,
        location: _sampleLocation,
        now: now ?? DateTime.now(),
        battery: 80,
        plain: plain,
      );

  static String formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)} '
        '${two(time.day)}/${two(time.month)}';
  }

  static final Map<String, String> _plainChars = () {
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    final map = <String, String>{};
    groups.forEach((plain, marked) {
      for (final char in marked.split('')) {
        map[char] = plain;
        map[char.toUpperCase()] = plain.toUpperCase();
      }
    });
    return map;
  }();

  static String stripDiacritics(String text) {
    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(_plainChars[char] ?? char);
    }
    return buffer.toString();
  }

  static const _gsmBasic =
      '@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !"#¤%&\'()*+,-./0123456789:;<=>?'
      '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà';
  static const _gsmExtended = '^{}\\[~]|€';

  /// Cách nhà mạng tính số tin: không dấu 160 ký tự/tin (153 nếu ghép nhiều tin),
  /// có dấu 70 ký tự/tin (67 nếu ghép).
  static SmsSize size(String text) {
    var gsmLength = 0;
    var unicode = false;
    for (final char in text.split('')) {
      if (_gsmBasic.contains(char)) {
        gsmLength += 1;
      } else if (_gsmExtended.contains(char)) {
        gsmLength += 2;
      } else {
        unicode = true;
        break;
      }
    }
    if (unicode) {
      final length = text.length;
      return SmsSize(
        characters: length,
        parts: length <= 70 ? 1 : (length / 67).ceil(),
        unicode: true,
      );
    }
    return SmsSize(
      characters: gsmLength,
      parts: gsmLength <= 160 ? 1 : (gsmLength / 153).ceil(),
      unicode: false,
    );
  }
}
