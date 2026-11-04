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
      leaveAppAfterCall: false,
    );
    await repository.save(saved);
    final loaded = await repository.load();
    expect(loaded.phoneStyle, PhoneStyle.xiaomi);
    expect(loaded.vibrateOnCall, isFalse);
    expect(loaded.lastDelay, const Duration(minutes: 5));
    expect(loaded.flipEnabled, isTrue);
    expect(loaded.sensitivity, TriggerSensitivity.high);
    expect(loaded.leaveAppAfterCall, isFalse);
  });

  test('Missing settings fall back to defaults', () async {
    final loaded = await SettingsRepository(StorageService()).load();
    expect(loaded.phoneStyle, PhoneStyle.auto);
    expect(loaded.vibrateOnCall, isTrue);
    expect(loaded.lastDelay, AppConstants.defaultCallDelay);
    // Mặc định gác máy xong thì về màn hình chính.
    expect(loaded.leaveAppAfterCall, isTrue);
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

  test(
    'Reply pause round-trips, defaults to 1 s and stays within 0.5–5 s',
    () async {
      final repository = SettingsRepository(StorageService());
      expect((await repository.load()).replyPause, const Duration(seconds: 1));
      await repository.save(
        const AppSettings().copyWith(
          replyPause: const Duration(milliseconds: 2500),
        ),
      );
      expect(
        (await repository.load()).replyPause,
        const Duration(milliseconds: 2500),
      );
      expect(
        const AppSettings().copyWith(replyPause: Duration.zero).replyPause,
        AppSettings.minReplyPause,
      );
      expect(
        const AppSettings()
            .copyWith(replyPause: const Duration(seconds: 30))
            .replyPause,
        AppSettings.maxReplyPause,
      );
    },
  );

  test(
    'Settings saved by an older version (with back tap) still load',
    () async {
      SharedPreferences.setMockInitialValues({
        'tron.settings':
            '{"flipEnabled":true,"knockEnabled":true,"replyPauseMs":"bad"}',
      });
      final loaded = await SettingsRepository(StorageService()).load();
      expect(loaded.flipEnabled, isTrue);
      expect(loaded.replyPause, AppSettings.defaultReplyPause);
      expect(loaded.toJson().containsKey('knockEnabled'), isFalse);
    },
  );

  test(
    'Older settings without a reply pause get 1 s; odd values are snapped',
    () async {
      for (final (json, expected) in [
        ('{"flipEnabled":true,"knockEnabled":false}', 1000),
        ('{"replyPauseMs":99999}', 5000),
        ('{"replyPauseMs":100}', 500),
        ('{"replyPauseMs":1234}', 1000),
        ('{"replyPauseMs":1800.0}', 2000),
      ]) {
        SharedPreferences.setMockInitialValues({'tron.settings': json});
        final loaded = await SettingsRepository(StorageService()).load();
        expect(loaded.replyPause.inMilliseconds, expected, reason: json);
      }
    },
  );
}
