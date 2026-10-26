import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final callAlarmServiceProvider = Provider<CallAlarmService>(
  (ref) => CallAlarmService(),
);

/// Đặt thông báo cuộc gọi đúng giờ, kể cả khi app đã nền hoặc máy đã khóa.
/// Mọi lỗi đều trả về false: đồng hồ trong app vẫn hoạt động như cũ.
class CallAlarmService {
  CallAlarmService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = 1001;
  static const channelId = 'incoming_calls';
  static const _channelName = 'Cuộc gọi đến';

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  /// Phát ra mã combo khi người dùng chạm vào thông báo cuộc gọi.
  Stream<String> get taps => _taps.stream;

  Future<void> init() async {
    if (_ready) {
      return;
    }
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final comboId = response.payload;
        if (comboId != null && comboId.isNotEmpty) {
          _taps.add(comboId);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            _channelName,
            importance: Importance.max,
          ),
        );
    _ready = true;
  }

  /// Trả về false nếu hệ thống từ chối (thiếu quyền, không hỗ trợ...).
  Future<bool> scheduleCall({
    required String comboId,
    required DateTime fireAt,
  }) async {
    try {
      await init();
      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Cuộc gọi đến',
        body: 'Chạm để nghe',
        // Đổi sang UTC giữ nguyên thời điểm tuyệt đối, không phụ thuộc múi giờ máy.
        scheduledDate: tz.TZDateTime.from(fireAt, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: comboId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancel() async {
    try {
      await _plugin.cancel(id: notificationId);
    } catch (_) {
      // Không có thông báo nào để hủy hoặc plugin chưa sẵn sàng.
    }
  }

  /// Mã combo nếu app được mở bằng cách chạm vào thông báo cuộc gọi.
  Future<String?> launchComboId() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        return details?.notificationResponse?.payload;
      }
    } catch (_) {
      // Không đọc được trạng thái khởi động từ thông báo: coi như mở thường.
    }
    return null;
  }

  Future<void> dispose() => _taps.close();
}
