import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/built_in_ringtone.dart';

final callAlarmServiceProvider = Provider<CallAlarmService>(
  (ref) => CallAlarmService(),
);

/// Đặt thông báo cuộc gọi đúng giờ, kể cả khi app đã nền hoặc máy đã khóa.
/// Mọi lỗi đều trả về false: đồng hồ trong app vẫn hoạt động như cũ.
class CallAlarmService {
  CallAlarmService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = 1001;
  static const _channelName = 'Cuộc gọi đến';

  /// Kênh cũ dùng âm mặc định của máy, xóa đi để không còn trong cài đặt.
  static const _legacyChannelId = 'incoming_calls';

  /// Cờ FLAG_INSISTENT của Android: chuông kêu lặp tới khi thông báo bị hủy
  /// hoặc người dùng mở thông báo.
  static const _flagInsistent = 4;

  /// Không ai bấm thì thông báo tự tắt, như một cuộc gọi nhỡ.
  static const ringTimeout = Duration(seconds: 60);

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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.deleteNotificationChannel(channelId: _legacyChannelId);
      for (final ringtone in BuiltInRingtone.values) {
        await android.createNotificationChannel(channelFor(ringtone));
      }
    }
    _ready = true;
  }

  @visibleForTesting
  static AndroidNotificationChannel channelFor(BuiltInRingtone ringtone) =>
      AndroidNotificationChannel(
        ringtone.channelId,
        '$_channelName · ${ringtone.label}',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound(ringtone.androidResource),
        // Đi theo âm lượng nhạc chuông của máy, như cuộc gọi thật.
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      );

  @visibleForTesting
  static AndroidNotificationDetails androidDetailsFor(
    BuiltInRingtone ringtone,
  ) => AndroidNotificationDetails(
    ringtone.channelId,
    '$_channelName · ${ringtone.label}',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    fullScreenIntent: true,
    sound: RawResourceAndroidNotificationSound(ringtone.androidResource),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    additionalFlags: Int32List.fromList([_flagInsistent]),
    timeoutAfter: ringTimeout.inMilliseconds,
  );

  /// Trả về false nếu hệ thống từ chối (thiếu quyền, không hỗ trợ...).
  Future<bool> scheduleCall({
    required String comboId,
    required DateTime fireAt,
    required BuiltInRingtone ringtone,
  }) async {
    try {
      await init();
      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Cuộc gọi đến',
        body: 'Chạm để nghe',
        // Đổi sang UTC giữ nguyên thời điểm tuyệt đối, không phụ thuộc múi giờ máy.
        scheduledDate: tz.TZDateTime.from(fireAt, tz.UTC),
        notificationDetails: NotificationDetails(
          android: androidDetailsFor(ringtone),
          iOS: const DarwinNotificationDetails(
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
