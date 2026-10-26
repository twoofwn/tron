import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/enums/call_interface.dart';
import '../../combo/providers/combo_provider.dart';
import '../../fake_call/providers/call_provider.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_provider.dart';
import '../services/gesture_detectors.dart';
import '../services/motion_trigger_service.dart';

/// Đang mở màn "Thử cử chỉ": cử chỉ chỉ hiển thị, không hẹn cuộc gọi.
final gestureTestingProvider = NotifierProvider<GestureTestingNotifier, bool>(
  GestureTestingNotifier.new,
);

class GestureTestingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setTesting(bool testing) => state = testing;
}

/// Giữ cảm biến theo cài đặt và biến cử chỉ thành cuộc gọi hẹn giờ.
/// Phải được watch ở gốc app để luôn hoạt động.
final motionActivationProvider = Provider<void>((ref) {
  final service = ref.watch(motionTriggerServiceProvider);
  ref.listen<AsyncValue<AppSettings>>(settingsProvider, (_, next) {
    final settings = next.value;
    if (settings == null || (!settings.flipEnabled && !settings.knockEnabled)) {
      service.stop();
      return;
    }
    service.start(
      flip: settings.flipEnabled,
      knock: settings.knockEnabled,
      sensitivity: settings.sensitivity,
    );
  }, fireImmediately: true);
  final subscription = service.triggers.listen(
    (event) => _onGesture(ref, event),
  );
  ref.onDispose(subscription.cancel);
});

Future<void> _onGesture(Ref ref, TriggerEvent event) async {
  if (ref.read(gestureTestingProvider)) {
    return;
  }
  // Đang có cuộc gọi chờ hoặc đang đổ thì không hẹn thêm.
  if (ref.read(callProvider).status != CallStatus.idle) {
    return;
  }
  final combos = await ref.read(comboListProvider.future);
  final selectedId = ref.read(selectedComboIdProvider);
  final combo =
      combos.where((item) => item.id == selectedId).firstOrNull ??
      combos.firstOrNull;
  if (combo == null) {
    return;
  }
  await ref
      .read(callProvider.notifier)
      .schedule(combo, ref.read(callDelayProvider));
  // Rung nhẹ để người dùng biết cử chỉ đã được nhận.
  await HapticFeedback.mediumImpact();
}
