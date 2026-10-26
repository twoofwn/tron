import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/constants/app_constants.dart';
import 'package:tron/core/services/storage_service.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/settings/repositories/settings_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Settings round-trip through storage', () async {
    final repository = SettingsRepository(StorageService());
    const saved = AppSettings(
      phoneStyle: PhoneStyle.xiaomi,
      vibrateOnCall: false,
      lastDelay: Duration(minutes: 5),
      flipEnabled: true,
      sensitivity: TriggerSensitivity.high,
    );
    await repository.save(saved);
    final loaded = await repository.load();
    expect(loaded.phoneStyle, PhoneStyle.xiaomi);
    expect(loaded.vibrateOnCall, isFalse);
    expect(loaded.lastDelay, const Duration(minutes: 5));
    expect(loaded.flipEnabled, isTrue);
    expect(loaded.sensitivity, TriggerSensitivity.high);
  });

  test('Missing settings fall back to defaults', () async {
    final loaded = await SettingsRepository(StorageService()).load();
    expect(loaded.phoneStyle, PhoneStyle.auto);
    expect(loaded.vibrateOnCall, isTrue);
    expect(loaded.lastDelay, AppConstants.defaultCallDelay);
  });

  test('Corrupt settings do not stop the app', () async {
    SharedPreferences.setMockInitialValues({'tron.settings': '{not json'});
    final loaded = await SettingsRepository(StorageService()).load();
    expect(loaded.phoneStyle, PhoneStyle.auto);
    expect(loaded.lastDelay, AppConstants.defaultCallDelay);
  });

  test('Unknown values in stored settings use defaults', () async {
    SharedPreferences.setMockInitialValues({
      'tron.settings':
          '{"phoneStyle":"nokia","vibrateOnCall":"yes","lastDelaySeconds":7}',
    });
    final loaded = await SettingsRepository(StorageService()).load();
    expect(loaded.phoneStyle, PhoneStyle.auto);
    expect(loaded.vibrateOnCall, isTrue);
    expect(loaded.lastDelay, AppConstants.defaultCallDelay);
  });
}
