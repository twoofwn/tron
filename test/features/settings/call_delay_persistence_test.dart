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
}
