import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sos_message.dart';

@immutable
class PickedContact {
  const PickedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

/// Trạng thái hẹn giờ "Báo an toàn" do Android giữ (chạy được khi app đóng).
@immutable
class CheckInStatus {
  const CheckInStatus({
    this.deadline,
    this.firedAt,
    this.sent = 0,
    this.total = 0,
    this.located = false,
    this.sending = false,
  });

  factory CheckInStatus.fromMap(Map<Object?, Object?> map) {
    DateTime? time(Object? value) {
      final millis = (value as num?)?.toInt() ?? 0;
      return millis <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    }

    return CheckInStatus(
      deadline: time(map['deadline']),
      firedAt: time(map['firedAt']),
      sent: (map['sent'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      located: map['located'] as bool? ?? false,
      sending: map['sending'] as bool? ?? false,
    );
  }

  /// Android gửi xong (lấy vị trí 10 giây + chờ SMS 30 giây) trong vòng
  /// khoảng 1 phút; quá lâu thì coi như tiến trình đã bị tắt giữa chừng.
  static const sendingTimeout = Duration(minutes: 2);

  /// Hạn báo an toàn; null nếu không hẹn giờ.
  final DateTime? deadline;

  /// Lần gần nhất app đã tự gửi SOS vì hết giờ (chưa được người dùng xem).
  final DateTime? firedAt;
  final int sent;
  final int total;
  final bool located;

  /// Android đang lấy vị trí và gửi tin sau khi hết giờ.
  final bool sending;

  bool get isActive => deadline != null;

  /// Đã hết giờ nhưng Android chưa bắt đầu gửi (báo thức có thể trễ vài giây,
  /// hoặc vài phút nếu không có quyền báo thức chính xác). Vẫn huỷ được.
  bool isOverdue([DateTime? now]) =>
      deadline != null && !deadline!.isAfter(now ?? DateTime.now());

  /// Đang gửi SOS. Cờ cũ quá [sendingTimeout] thì bỏ qua để không quay mãi.
  bool isSending([DateTime? now]) =>
      sending &&
      firedAt != null &&
      (now ?? DateTime.now()).difference(firedAt!) < sendingTimeout;

  /// Có kết quả lần tự gửi để báo cho người dùng.
  bool hasResult([DateTime? now]) => firedAt != null && !isSending(now);
}

/// Lệnh SOS cần code Android (`SosTools.kt`, `SosCheckIn.kt`).
/// Nền tảng khác (test, web, iOS) thì báo chưa hỗ trợ, không làm vỡ app.
class SosPlatform {
  SosPlatform([this._channel = const MethodChannel('tron/sos')]);

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  /// Mở bảng chọn danh bạ của hệ thống (không cần quyền đọc danh bạ).
  Future<PickedContact?> pickContact() async {
    final result = await _invoke<Map<Object?, Object?>>('pickContact');
    final phone = result?['phone'] as String?;
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }
    return PickedContact(name: result?['name'] as String? ?? '', phone: phone);
  }

  Future<SosLocation?> locate({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final result = await _invoke<Map<Object?, Object?>>('locate', {
        'timeoutMs': timeout.inMilliseconds,
      });
      if (result == null) {
        return null;
      }
      return SosLocation(
        latitude: (result['latitude'] as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
        accuracy: (result['accuracy'] as num?)?.toDouble(),
      );
    } on PlatformException {
      return null;
    }
  }

  /// Trả về null nếu đã gửi, hoặc mã lỗi.
  Future<String?> sendSms(String phone, String text) async {
    try {
      if (!isSupported) {
        return 'unsupported';
      }
      return await _invoke<String>('sendSms', {'phone': phone, 'text': text});
    } on PlatformException catch (error) {
      return error.code;
    }
  }

  /// Gọi thẳng (có quyền) hoặc mở sẵn màn quay số. Trả về true nếu đã gọi thẳng.
  Future<bool> call(String phone) async {
    try {
      return await _invoke<String>('call', {'phone': phone}) == 'call';
    } on PlatformException {
      return false;
    }
  }

  /// Mở màn quay số (dùng cho số khẩn cấp 113/115: Android không cho gọi thẳng).
  Future<void> dial(String phone) async {
    try {
      await _invoke<String>('dial', {'phone': phone});
    } on PlatformException {
      // Máy không có trình quay số.
    }
  }

  Future<int?> battery() async {
    try {
      return await _invoke<int>('battery');
    } on PlatformException {
      return null;
    }
  }

  /// Trả về false nếu Android chỉ cho đặt báo thức không chính xác (có thể trễ vài phút).
  Future<bool> startCheckIn(DateTime deadline, String payload) async =>
      await _invoke<bool>('startCheckIn', {
        'deadline': deadline.millisecondsSinceEpoch,
        'payload': payload,
      }) ??
      false;

  Future<void> cancelCheckIn() => _invoke<void>('cancelCheckIn');

  Future<CheckInStatus> checkInStatus() async {
    final result = await _invoke<Map<Object?, Object?>>('checkInStatus');
    return result == null
        ? const CheckInStatus()
        : CheckInStatus.fromMap(result);
  }

  Future<void> clearCheckInResult() => _invoke<void>('clearCheckInResult');
}

enum SosPermission {
  sms('Gửi SMS', 'Tự gửi tin nhắn SOS'),
  call('Gọi điện', 'Tự gọi người liên hệ đầu tiên'),
  location('Vị trí', 'Gửi kèm vị trí của bạn'),
  notifications('Thông báo', 'Nhắc trước khi tự gửi khi hẹn giờ'),
  exactAlarm('Báo thức chính xác', 'Gửi đúng giờ khi hẹn giờ');

  const SosPermission(this.label, this.purpose);
  final String label;
  final String purpose;
}

class SosPermissionService {
  const SosPermissionService();

  Permission _permission(SosPermission permission) => switch (permission) {
    SosPermission.sms => Permission.sms,
    SosPermission.call => Permission.phone,
    SosPermission.location => Permission.locationWhenInUse,
    SosPermission.notifications => Permission.notification,
    SosPermission.exactAlarm => Permission.scheduleExactAlarm,
  };

  Future<bool> isGranted(SosPermission permission) async {
    try {
      return (await _permission(permission).status).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<Map<SosPermission, bool>> statuses() async => {
    for (final permission in SosPermission.values)
      permission: await isGranted(permission),
  };

  /// Trả về true nếu đã được cấp. Bị từ chối hẳn thì mở cài đặt của app.
  Future<bool> request(SosPermission permission) async {
    try {
      final status = await _permission(permission).request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
}
