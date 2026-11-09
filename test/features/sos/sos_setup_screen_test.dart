import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/features/sos/models/sos_settings.dart';
import 'package:tron/features/sos/providers/sos_providers.dart';
import 'package:tron/features/sos/screens/sos_setup_screen.dart';
import 'package:tron/features/sos/services/sos_platform.dart';
import 'package:tron/features/sos/widgets/check_in_card.dart';

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
    bool settle = true,
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Vòng xoay "đang gửi" chạy mãi nên không chờ hết hiệu ứng.
      await tester.pump();
      await tester.pump();
    }
    return container;
  }

  /// Kéo thanh trượt hẹn giờ tới đúng nấc [duration].
  Future<void> pickDuration(WidgetTester tester, Duration duration) async {
    final slider = find.byKey(const ValueKey('check-in-slider'));
    await tester.ensureVisible(slider);
    final step = CheckInNotifier.durations.indexOf(duration);
    expect(step, isNonNegative);
    tester.widget<Slider>(slider).onChanged!(step.toDouble());
    await tester.pump();
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
    await pickDuration(tester, const Duration(hours: 1));
    expect(find.text('Tự gửi SOS sau 1 giờ'), findsOneWidget);
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

  test('Check-in steps run from 30 seconds to 3 hours', () {
    final steps = CheckInNotifier.durations;
    expect(steps.first, const Duration(seconds: 30));
    expect(steps.last, const Duration(hours: 3));
    expect(steps, contains(CheckInNotifier.defaultDuration));
    for (var i = 1; i < steps.length; i++) {
      expect(steps[i] > steps[i - 1], isTrue);
    }
    expect(durationLabel(const Duration(seconds: 90)), '1 phút 30 giây');
    expect(durationLabel(const Duration(minutes: 155)), '2 giờ 35 phút');
  });

  testWidgets('The shortest check-in is 30 seconds', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.tron.sos.v1':
          '{"contacts":[{"id":"a","name":"Mẹ","phone":"0901234567"}]}',
    });
    await open(tester);
    expect(find.text('Tự gửi SOS sau 30 phút'), findsOneWidget);
    await pickDuration(tester, const Duration(seconds: 30));
    expect(find.text('Tự gửi SOS sau 30 giây'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await tester.pumpAndSettle();
    final left = platform.checkIns.single.$1.difference(DateTime.now());
    expect(left.inSeconds, inInclusiveRange(28, 30));

    await tester.tap(find.text('Tôi an toàn'));
    await tester.pumpAndSettle();
    expect(platform.cancelledCheckIns, 1);
  });

  testWidgets('The Home banner has a readable "I am safe" button', (
    tester,
  ) async {
    platform.status = CheckInStatus(
      deadline: DateTime.now().add(const Duration(minutes: 5)),
    );
    final container = ProviderContainer(
      overrides: [sosPlatformProvider.overrideWithValue(platform)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CheckInBanner())),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('check-in-safe'));
    expect(button, findsOneWidget);
    final style = tester.widget<FilledButton>(button).style!;
    // Chữ tối trên nền xanh, không còn chữ vàng.
    expect(
      style.foregroundColor!.resolve({})!.computeLuminance(),
      lessThan(0.1),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(platform.cancelledCheckIns, 1);
  });

  test('Check-in status tells waiting, sending and done apart', () {
    final now = DateTime(2026, 11, 9, 10);
    final waiting = CheckInStatus(
      deadline: now.add(const Duration(seconds: 1)),
    );
    expect(waiting.isOverdue(now), isFalse);
    final overdue = CheckInStatus(deadline: now);
    expect(overdue.isOverdue(now), isTrue);

    final sending = CheckInStatus(firedAt: now, sending: true);
    expect(sending.isSending(now), isTrue);
    expect(sending.hasResult(now), isFalse);
    // Cờ "đang gửi" quá cũ (tiến trình bị tắt giữa chừng) thì hiện kết quả.
    final stale = now.add(CheckInStatus.sendingTimeout);
    expect(sending.isSending(stale), isFalse);
    expect(sending.hasResult(stale), isTrue);

    final done = CheckInStatus(firedAt: now, sent: 1, total: 1);
    expect(done.hasResult(now), isTrue);
    expect(
      CheckInStatus.fromMap({'firedAt': 5, 'sending': true}).sending,
      isTrue,
    );
  });

  testWidgets('At zero the timer turns into "sending", still cancellable', (
    tester,
  ) async {
    platform.status = CheckInStatus(
      deadline: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    SharedPreferences.setMockInitialValues({
      'flutter.tron.sos.v1':
          '{"contacts":[{"id":"a","name":"Mẹ","phone":"0901234567"}]}',
    });
    await open(tester, settle: false);

    expect(find.text('Hết giờ · đang gửi SOS…'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-in-countdown')), findsNothing);
    await tester.tap(find.text('Tôi an toàn'));
    await tester.pumpAndSettle();
    expect(platform.cancelledCheckIns, 1);
    expect(find.text('Bắt đầu hẹn giờ'), findsOneWidget);
  });

  testWidgets('While Android sends, the screen waits then shows the result', (
    tester,
  ) async {
    platform.status = CheckInStatus(firedAt: DateTime.now(), sending: true);
    SharedPreferences.setMockInitialValues({
      'flutter.tron.sos.v1':
          '{"contacts":[{"id":"a","name":"Mẹ","phone":"0901234567"}]}',
    });
    await open(tester, settle: false);

    expect(find.text('Đang gửi SOS…'), findsOneWidget);
    expect(find.textContaining('nhắn tin cho 1 người'), findsOneWidget);
    expect(find.text('Tôi an toàn'), findsNothing);
    expect(find.textContaining('Đã tự gửi SOS'), findsNothing);

    platform.status = CheckInStatus(
      firedAt: platform.status.firedAt,
      sent: 1,
      total: 1,
      located: true,
    );
    await tester.pump(CheckInNotifier.pollInterval);
    await tester.pumpAndSettle();
    expect(find.text('Đang gửi SOS…'), findsNothing);
    expect(find.textContaining('Đã tự gửi SOS'), findsOneWidget);
    expect(find.textContaining('1/1 tin kèm vị trí'), findsOneWidget);
  });

  testWidgets('The Home banner shows sending without a cancel button', (
    tester,
  ) async {
    platform.status = CheckInStatus(firedAt: DateTime.now(), sending: true);
    final container = ProviderContainer(
      overrides: [sosPlatformProvider.overrideWithValue(platform)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CheckInBanner())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Đang gửi SOS…'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-in-safe')), findsNothing);

    platform.status = const CheckInStatus();
    await tester.pump(CheckInNotifier.pollInterval);
    await tester.pump();
    expect(find.byKey(const ValueKey('check-in-banner')), findsNothing);
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
