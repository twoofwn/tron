import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/constants/app_constants.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/features/settings/providers/settings_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Selected call delay is restored on the next launch', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(settingsProvider.future);
    expect(first.read(callDelayProvider), AppConstants.defaultCallDelay);

    await first
        .read(callDelayProvider.notifier)
        .select(const Duration(minutes: 1));
    expect(first.read(callDelayProvider), const Duration(minutes: 1));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(settingsProvider.future);
    expect(second.read(callDelayProvider), const Duration(minutes: 1));
  });

  test('The 10, 15 and 30 minute delays can be chosen and restored', () async {
    for (final minutes in [10, 15, 30]) {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(settingsProvider.future);
      await first
          .read(callDelayProvider.notifier)
          .select(Duration(minutes: minutes));

      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(settingsProvider.future);
      expect(second.read(callDelayProvider), Duration(minutes: minutes));
    }
  });

  test('Every delay option has a distinct label', () {
    final labels = AppConstants.callDelays.map(delayLabel).toList();
    expect(labels, [
      '10 giây',
      '30 giây',
      '1 phút',
      '5 phút',
      '10 phút',
      '15 phút',
      '30 phút',
    ]);
    expect(labels.toSet().length, labels.length);
  });

  test('The countdown switches to minutes and seconds from one minute', () {
    expect(
      countdownLabel(const Duration(seconds: 9, milliseconds: 400)),
      '10 giây',
    );
    expect(
      countdownLabel(const Duration(seconds: 58, milliseconds: 500)),
      '59 giây',
    );
    expect(
      countdownLabel(const Duration(seconds: 59, milliseconds: 500)),
      '1:00',
    );
    expect(countdownLabel(const Duration(minutes: 14, seconds: 56)), '14:57');
    expect(countdownLabel(const Duration(minutes: 29, seconds: 59)), '30:00');
  });
}
