import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../services/phone_style_detector.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(storageServiceProvider)),
);

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> modify(AppSettings Function(AppSettings current) change) async {
    final next = change(await future);
    await ref.read(settingsRepositoryProvider).save(next);
    state = AsyncData(next);
  }
}

/// Kiểu máy đang áp dụng: nếu người dùng chọn tay thì dùng lựa chọn đó.
final resolvedPhoneStyleProvider = FutureProvider<PhoneStyle>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  if (settings.phoneStyle != PhoneStyle.auto) {
    return settings.phoneStyle;
  }
  return detectDevicePhoneStyle();
});
