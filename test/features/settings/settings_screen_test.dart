import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/features/activation/services/permission_service.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/settings/providers/settings_provider.dart';
import 'package:tron/features/settings/screens/settings_screen.dart';

Future<ProviderContainer> pumpSettings(
  WidgetTester tester, {
  Size size = const Size(390, 1400),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      permissionSnapshotProvider.overrideWith(
        (ref) => Future.value(
          const PermissionSnapshot(
            notifications: true,
            exactAlarm: true,
            batteryUnrestricted: false,
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const SettingsScreen(),
        ),
      ),
    ),
  );
  await container.read(settingsProvider.future);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Choosing a phone style is saved and turns auto-detect off', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    expect(
      (await container.read(settingsProvider.future)).phoneStyle,
      PhoneStyle.auto,
    );
    await tester.tap(find.text('Samsung'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).phoneStyle,
      PhoneStyle.samsung,
    );
  });

  testWidgets('Auto-detect checkbox returns the choice to the device', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('Samsung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tự nhận diện theo máy đang dùng'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).phoneStyle,
      PhoneStyle.auto,
    );
  });

  testWidgets('Vibration switch is saved', (tester) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('Rung khi có cuộc gọi'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(settingsProvider.future)).vibrateOnCall,
      isFalse,
    );
  });

  testWidgets('Compact screen with large text does not overflow', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
