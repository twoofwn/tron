import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

enum CallPermission { notifications, exactAlarm, batteryUnrestricted }

@immutable
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.notifications,
    required this.exactAlarm,
    required this.batteryUnrestricted,
  });

  final bool notifications;

  /// Chỉ có ý nghĩa trên Android; iOS luôn coi là đã cấp.
  final bool exactAlarm;
  final bool batteryUnrestricted;
}

class PermissionService {
  const PermissionService();

  bool supports(CallPermission permission) => switch (permission) {
    CallPermission.notifications => true,
    CallPermission.exactAlarm || CallPermission.batteryUnrestricted =>
      defaultTargetPlatform == TargetPlatform.android,
  };

  /// Lỗi đọc quyền coi như chưa cấp, không làm vỡ màn hình.
  Future<bool> isGranted(CallPermission permission) async {
    if (!supports(permission)) {
      return true;
    }
    try {
      return (await _permission(permission).status).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<PermissionSnapshot> snapshot() async => PermissionSnapshot(
    notifications: await isGranted(CallPermission.notifications),
    exactAlarm: await isGranted(CallPermission.exactAlarm),
    batteryUnrestricted: await isGranted(CallPermission.batteryUnrestricted),
  );

  Future<void> request(CallPermission permission) async {
    await _permission(permission).request();
  }

  /// Hiện khi khóa máy: plugin không đọc được trạng thái, chỉ mở cài đặt.
  Future<void> openFullScreenSettings() async {
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestFullScreenIntentPermission();
    } catch (_) {
      // Không mở được cài đặt trên nền tảng này.
    }
  }

  Permission _permission(CallPermission permission) => switch (permission) {
    CallPermission.notifications => Permission.notification,
    CallPermission.exactAlarm => Permission.scheduleExactAlarm,
    CallPermission.batteryUnrestricted => Permission.ignoreBatteryOptimizations,
  };
}

final permissionSnapshotProvider =
    FutureProvider.autoDispose<PermissionSnapshot>(
      (ref) => ref.watch(permissionServiceProvider).snapshot(),
    );
