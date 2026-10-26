import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/enums/call_interface.dart';
import '../../combo/providers/combo_provider.dart';
import '../../fake_call/providers/call_provider.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_provider.dart';
import '../services/background_guard.dart';
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
  final subscription = service.triggers.listen((_) => scheduleFromTrigger(ref));
  ref.onDispose(subscription.cancel);
});

/// Giữ dịch vụ nền Android đúng theo cài đặt "Sẵn sàng khi tắt màn hình".
/// Chỉ có tác dụng khi đã bật ít nhất một cử chỉ.
final backgroundArmingProvider = Provider<void>((ref) {
  final guard = ref.watch(backgroundGuardProvider);
  ref.listen<bool>(settingsProvider.select(_isArmed), (_, armed) {
    unawaited(armed ? guard.start() : guard.stop());
  }, fireImmediately: true);
});

bool _isArmed(AsyncValue<AppSettings> settings) {
  final value = settings.value;
  return value != null &&
      value.backgroundArmed &&
      (value.flipEnabled || value.knockEnabled);
}

/// Đường dẫn tron://trigger từ phím tắt Back Tap (iOS) hoặc liên kết khác.
bool isTriggerLink(Uri uri) => uri.scheme == 'tron' && uri.host == 'trigger';

/// Nguồn đường dẫn mở app; tách ra để test toàn app không cần kênh của app_links.
abstract interface class DeepLinkSource {
  Stream<Uri> get uris;

  Future<Uri?> initialUri();
}

class AppLinksSource implements DeepLinkSource {
  final _links = AppLinks();

  @override
  Stream<Uri> get uris => _links.uriLinkStream;

  @override
  Future<Uri?> initialUri() => _links.getInitialLink();
}

final deepLinkSourceProvider = Provider<DeepLinkSource>(
  (ref) => AppLinksSource(),
);

/// Nghe đường dẫn tron://trigger, kể cả khi app được mở từ đường dẫn đó.
final triggerLinkProvider = Provider<void>((ref) {
  final source = ref.watch(deepLinkSourceProvider);
  final subscription = source.uris.listen((uri) {
    if (isTriggerLink(uri)) {
      unawaited(scheduleFromTrigger(ref));
    }
  }, onError: (_) {});
  ref.onDispose(subscription.cancel);
  unawaited(() async {
    try {
      final initial = await source.initialUri();
      if (initial != null && isTriggerLink(initial)) {
        await scheduleFromTrigger(ref);
      }
    } catch (_) {
      // Không đọc được liên kết khởi động: app vẫn mở bình thường.
    }
  }());
});

/// Hẹn cuộc gọi cho combo đang chọn; dùng chung cho cử chỉ và đường dẫn tron://trigger.
Future<void> scheduleFromTrigger(Ref ref) async {
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
