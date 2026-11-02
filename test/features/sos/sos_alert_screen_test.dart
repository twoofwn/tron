import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/app/router/route_names.dart';
import 'package:tron/core/config/app_config.dart';
import 'package:tron/features/fake_call/themes/call_theme.dart';
import 'package:tron/features/fake_call/widgets/call_action_button.dart';
import 'package:tron/features/fake_call/widgets/in_call_view.dart';
import 'package:tron/features/sos/models/sos_settings.dart';
import 'package:tron/features/sos/providers/sos_providers.dart';
import 'package:tron/features/sos/screens/sos_alert_screen.dart';
import 'package:tron/features/sos/services/sos_platform.dart';
import 'package:tron/shared/enums/call_interface.dart';

import 'sos_fakes.dart';

const _mom = SosContact(id: 'mom', name: 'Mẹ', phone: '0901234567');
const _brother = SosContact(id: 'bro', name: 'Anh', phone: '0912345678');

void main() {
  late FakeSosPlatform platform;
  late FakeSosPermissions permissions;

  void saveSettings(SosSettings settings) {
    SharedPreferences.setMockInitialValues({
      'flutter.${AppConfig.sosKey}': jsonEncode(settings.toJson()),
    });
  }

  setUp(() {
    platform = FakeSosPlatform();
    permissions = FakeSosPermissions();
  });

  Future<void> open(
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sosPlatformProvider.overrideWithValue(platform),
          sosPermissionServiceProvider.overrideWithValue(permissions),
        ],
        child: MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (context) => settings.name == RouteNames.sosAlert
                ? const SosAlertScreen()
                : Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, RouteNames.sosAlert),
                      child: const Text('open sos'),
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sos'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancelling during the countdown sends nothing', (tester) async {
    saveSettings(const SosSettings(contacts: [_mom], countdownSeconds: 5));
    await open(tester);
    expect(find.text('5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('HỦY'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('open sos'), findsOneWidget);
    expect(platform.sms, isEmpty);
    expect(platform.calls, isEmpty);
  });

  testWidgets('After the countdown every contact gets the SMS and the first '
      'is called', (tester) async {
    saveSettings(
      const SosSettings(contacts: [_mom, _brother], countdownSeconds: 3),
    );
    await open(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(platform.sms.map((item) => item.$1), [_mom.phone, _brother.phone]);
    final text = platform.sms.first.$2;
    expect(text, contains('https://maps.google.com/?q=10.500000,106.250000'));
    expect(text, isNot(contains('{vitri}')));
    expect(platform.calls, [_mom.phone]);
    expect(find.text('Đã gửi SOS'), findsOneWidget);
    expect(find.textContaining('Gọi người tiếp theo: Anh'), findsOneWidget);

    await tester.tap(find.textContaining('Gọi người tiếp theo'));
    await tester.pumpAndSettle();
    expect(platform.calls, [_mom.phone, _brother.phone]);

    await tester.tap(find.text('113 · Công an'));
    expect(platform.dials, ['113']);
  });

  testWidgets('A failed SMS can be resent and calling can be turned off', (
    tester,
  ) async {
    platform.failingPhones.add(_brother.phone);
    saveSettings(
      const SosSettings(
        contacts: [_mom, _brother],
        countdownSeconds: 0,
        autoCall: false,
      ),
    );
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Chưa gửi được hết'), findsOneWidget);
    expect(platform.calls, isEmpty);
    platform.failingPhones.clear();
    await tester.tap(find.text('Gửi lại'));
    await tester.pumpAndSettle();
    expect(
      platform.sms.where((item) => item.$1 == _brother.phone),
      hasLength(2),
    );
    expect(find.text('Gửi lại'), findsNothing);
  });

  testWidgets('Missing permissions are asked for once SOS starts', (
    tester,
  ) async {
    permissions.granted.clear();
    platform.location = null;
    saveSettings(const SosSettings(contacts: [_mom], countdownSeconds: 0));
    await open(tester);
    await tester.pumpAndSettle();

    expect(
      permissions.requested,
      containsAll([
        SosPermission.sms,
        SosPermission.location,
        SosPermission.call,
      ]),
    );
    expect(platform.sms.single.$2, contains('(không lấy được vị trí)'));
    expect(find.textContaining('Không lấy được vị trí'), findsOneWidget);
  });

  testWidgets('Without contacts SOS offers emergency numbers and setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Chưa có người liên hệ'), findsOneWidget);
    expect(find.text('Thiết lập SOS'), findsOneWidget);
    expect(find.text('115 · Cấp cứu'), findsOneWidget);
    expect(platform.sms, isEmpty);
  });

  testWidgets('Holding the hang-up button triggers SOS instead of hanging up', (
    tester,
  ) async {
    var hangUps = 0;
    var sos = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InCallView(
            caller: 'Mẹ',
            theme: CallTheme.of(CallInterface.phone),
            elapsed: Duration.zero,
            isMuted: false,
            isSpeaker: false,
            onToggleMute: () {},
            onToggleSpeaker: () {},
            onHangUp: () => hangUps++,
            onSos: () => sos++,
          ),
        ),
      ),
    );
    final button = find.byWidgetPredicate(
      (widget) => widget is CallButton && widget.label == 'Kết thúc',
    );

    await tester.tap(button);
    await tester.pump();
    expect((hangUps, sos), (1, 0));

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(CallButton.holdDuration);
    await gesture.up();
    await tester.pump();
    expect((hangUps, sos), (1, 1));
  });

  testWidgets('SOS screens fit a small phone with large text', (tester) async {
    saveSettings(
      const SosSettings(
        contacts: [
          SosContact(
            id: 'a',
            name: 'Người thân có tên rất dài',
            phone: '0901234567',
          ),
          _brother,
        ],
        countdownSeconds: 3,
      ),
    );
    await open(tester, size: const Size(320, 568), textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi SOS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
