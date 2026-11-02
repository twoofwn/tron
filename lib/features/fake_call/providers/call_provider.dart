import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/built_in_ringtone.dart';
import '../../../app/providers/app_foreground_provider.dart';
import '../../../shared/enums/call_interface.dart';
import '../../activation/services/call_alarm_service.dart';
import '../../combo/models/combo_model.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_provider.dart';

class CallState {
  const CallState({
    this.status = CallStatus.idle,
    this.combo,
    this.remaining = Duration.zero,
    this.scheduledAt,
  });
  final CallStatus status;
  final ComboModel? combo;
  final Duration remaining;
  final DateTime? scheduledAt;
}

final callDelayProvider = NotifierProvider<CallDelayNotifier, Duration>(
  CallDelayNotifier.new,
);

class CallDelayNotifier extends Notifier<Duration> {
  @override
  Duration build() =>
      ref.watch(settingsProvider).value?.lastDelay ??
      AppConstants.defaultCallDelay;

  Future<void> select(Duration duration) async {
    state = duration;
    await ref
        .read(settingsProvider.notifier)
        .modify((current) => current.copyWith(lastDelay: duration));
  }
}

final callProvider = NotifierProvider<CallNotifier, CallState>(
  CallNotifier.new,
);

class CallNotifier extends Notifier<CallState> {
  Timer? _timer;
  // Lần đặt báo thức gần nhất; phải xong trước khi hủy, nếu không báo thức có thể còn sót.
  Future<bool>? _arming;

  @override
  CallState build() {
    ref.onDispose(() => _timer?.cancel());
    return const CallState();
  }

  /// Trả về false nếu chỉ đổ chuông được khi app đang mở (không đặt được báo thức).
  Future<bool> schedule(ComboModel combo, Duration delay) {
    _timer?.cancel();
    final deadline = DateTime.now().add(delay);
    state = CallState(
      status: CallStatus.scheduled,
      combo: combo,
      remaining: delay,
      scheduledAt: deadline,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        // Đổ lúc app ở nền: thông báo báo thức cùng lúc hiện màn gọi, không hủy nó.
        _ring(combo, keepAlarm: !ref.read(appForegroundProvider));
      } else {
        state = CallState(
          status: CallStatus.scheduled,
          combo: combo,
          remaining: remaining,
          scheduledAt: deadline,
        );
      }
    });
    final arming = _arm(combo, deadline);
    _arming = arming;
    return arming;
  }

  Future<bool> _arm(ComboModel combo, DateTime fireAt) async {
    final alarm = ref.read(callAlarmServiceProvider);
    final ringtone = BuiltInRingtone.resolve(
      type: combo.ringtoneType,
      callInterface: combo.callInterface,
      phoneStyle: await _phoneStyle(),
    );
    return alarm.scheduleCall(
      comboId: combo.id,
      fireAt: fireAt,
      ringtone: ringtone,
    );
  }

  Future<PhoneStyle> _phoneStyle() async {
    try {
      return await ref.read(resolvedPhoneStyleProvider.future);
    } catch (_) {
      return PhoneStyle.samsung;
    }
  }

  /// App vừa lên màn hình trong lúc thông báo đang đổ chuông: tắt thông báo
  /// để chỉ còn app đổ chuông, không phát chồng hai chuông.
  void silenceAlarm() {
    if (state.status == CallStatus.ringing) {
      _cancelAlarm();
    }
  }

  /// Mở app từ thông báo cuộc gọi: đổ chuông ngay, không chờ hẹn giờ nữa.
  void ringNow(ComboModel combo) {
    if (state.status == CallStatus.ringing ||
        state.status == CallStatus.inProgress) {
      return;
    }
    _ring(combo);
  }

  void cancel() {
    _timer?.cancel();
    _cancelAlarm();
    state = const CallState();
  }

  void _ring(ComboModel combo, {bool keepAlarm = false}) {
    _timer?.cancel();
    if (!keepAlarm) {
      _cancelAlarm();
    }
    state = CallState(status: CallStatus.ringing, combo: combo);
  }

  void _cancelAlarm() {
    final alarm = ref.read(callAlarmServiceProvider);
    final arming = _arming;
    _arming = null;
    unawaited(() async {
      await arming;
      await alarm.cancel();
    }());
  }

  void answer() {
    _cancelAlarm();
    state = CallState(status: CallStatus.inProgress, combo: state.combo);
  }
}
