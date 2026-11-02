import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/features/sos/models/sos_settings.dart';
import 'package:tron/features/sos/providers/sos_providers.dart';
import 'package:tron/features/sos/screens/sos_setup_screen.dart';
import 'package:tron/features/sos/services/sos_platform.dart';

import 'sos_fakes.dart';

void main() {
  late FakeSosPlatform platform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = FakeSosPlatform();
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        sosPlatformProvider.overrideWithValue(platform),
        sosPermissionServiceProvider.overrideWithValue(FakeSosPermissions()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SosSetupScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> addByHand(WidgetTester tester, String name, String phone) async {
    await tester.tap(find.text('Nhập số'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên (không bắt buộc)'),
      name,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Số điện thoại'),
      phone,
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
  }

  testWidgets('Adding a contact by hand enables the SOS button', (
    tester,
  ) async {
    final container = await open(tester);
    expect(
      find.text('Chưa có ai. Thêm ít nhất một người để dùng SOS.'),
      findsOneWidget,
    );
    expect(find.text('Gửi SOS ngay'), findsNothing);

    await addByHand(tester, 'Mẹ', '12');
    expect(find.text('Nhập số điện thoại hợp lệ.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Số điện thoại'),
      '0901 234 567',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Mẹ'), findsOneWidget);
    expect(find.text('0901234567 · gọi trước'), findsOneWidget);
    expect(find.text('Gửi SOS ngay'), findsOneWidget);
    final saved = await container.read(sosSettingsProvider.future);
    expect(saved.contacts.single.phone, '0901234567');
  });

  testWidgets('The message can be edited, previewed and restored', (
    tester,
  ) async {
    final container = await open(tester);
    final field = find.byKey(const ValueKey('sos-template'));
    await tester.enterText(field, 'Cứu mình ');
    await tester.pump();
    // Ô nhập đang focus sẽ tự cuộn về con trỏ; bỏ focus để cuộn tới chip.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final chip = find.widgetWithText(ActionChip, 'Vị trí');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('sos-preview'))).data,
      startsWith('Cứu mình https://maps.google.com/?q='),
    );
    await tester.ensureVisible(find.text('Lưu nội dung'));
    await tester.tap(find.text('Lưu nội dung'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(sosSettingsProvider.future)).template,
      'Cứu mình {vitri}',
    );

    ScaffoldMessenger.of(tester.element(find.byType(SosSetupScreen)))
        .removeCurrentSnackBar();
    await tester.ensureVisible(find.text('Khôi phục mặc định'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khôi phục mặc định'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(sosSettingsProvider.future)).template,
      SosSettings.defaultTemplate,
    );
  });

  testWidgets('A running check-in shows the time left and can be stopped', (
    tester,
  ) async {
    platform.status = CheckInStatus(
      deadline: DateTime.now().add(const Duration(minutes: 20)),
    );
    SharedPreferences.setMockInitialValues({
      'flutter.tron.sos.v1':
          '{"contacts":[{"id":"a","name":"Mẹ","phone":"0901234567"}]}',
    });
    await open(tester);

    expect(find.byKey(const ValueKey('check-in-countdown')), findsOneWidget);
    expect(find.textContaining('19:5'), findsOneWidget);
    await tester.tap(find.text('Tôi an toàn'));
    await tester.pumpAndSettle();
    expect(platform.cancelledCheckIns, 1);
    expect(find.text('Bắt đầu hẹn giờ'), findsOneWidget);
  });

  testWidgets('Starting a check-in hands the deadline to Android', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flutter.tron.sos.v1':
          '{"contacts":[{"id":"a","name":"Mẹ","phone":"0901234567"}]}',
    });
    await open(tester);
    await tester.tap(find.text('1 giờ'));
    await tester.pump();
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await tester.pumpAndSettle();

    final deadline = platform.checkIns.single.$1;
    expect(
      deadline.difference(DateTime.now()).inMinutes,
      inInclusiveRange(58, 60),
    );
    expect(find.text('Tôi an toàn'), findsOneWidget);

    await tester.tap(find.text('Tôi an toàn'));
    await tester.pumpAndSettle();
    expect(platform.cancelledCheckIns, 1);
  });

  testWidgets('The setup screen fits a small phone with large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'flutter.tron.sos.v1': '{"contacts":[{"id":"a","name":"Người thân có tên rất dài","phone":"0901234567"}]}',
    });
    await open(tester, size: const Size(320, 640), textScale: 1.6);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
