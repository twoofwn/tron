import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/app/app.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/providers/combo_provider.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/shared/enums/call_interface.dart';
import 'package:tron/features/sharing/repositories/sharing_repository.dart';

class SilentAudioService extends AudioService {
  SilentAudioService() : super(FileService());
  @override
  Future<void> stop() async {}
  @override
  Future<void> ring(ComboModel combo) async {}
  @override
  Future<void> conversation(ComboModel combo, String dialogue) async {}
  @override
  Future<void> speak(String dialogue) async {}
  @override
  void dispose() {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold', 'black']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> start(
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
          audioServiceProvider.overrideWithValue(SilentAudioService()),
          sharingRepositoryProvider.overrideWith(
            (ref) => SharingRepository(
              ref.watch(fileServiceProvider),
              createId: () => '7c2a1000-0000-4000-a000-000000000000',
            ),
          ),
        ],
        child: const RepaintBoundary(
          key: ValueKey('app-preview'),
          child: TronApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home selection, timer changes, cancellation and theme switch', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Cần lối thoát?'), findsOneWidget);
    final context = tester.element(find.byType(TronApp));
    final container = ProviderScope.containerOf(context);
    await tester.tap(find.text('Mẹ gọi về nhà'));
    await tester.pump();
    expect(container.read(selectedComboIdProvider), endsWith('222222222222'));
    await tester.tap(find.text('10 giây'));
    await tester.pump();
    await tester.tap(find.text('Hẹn giờ · gọi sau 10 giây'));
    await tester.pump();
    expect(container.read(callProvider).status, CallStatus.scheduled);
    await tester.tap(find.text('Hủy cuộc gọi chờ'));
    await tester.pump();
    expect(container.read(callProvider).status, CallStatus.idle);
    await tester.tap(find.byTooltip('Đổi giao diện sáng / tối'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Cần lối thoát?'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Form validates, creates a combo and persists it', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('+ Tạo combo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu combo'));
    await tester.pumpAndSettle();
    expect(find.text('Hãy đặt tên cho combo của bạn'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Shipper gọi nhận hàng');
    await tester.tap(find.text('Lưu combo'));
    await tester.pumpAndSettle();
    expect(find.text('Shipper gọi nhận hàng'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TronApp)),
    );
    expect((await container.read(comboListProvider.future)).length, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Export creates actual QR payload and import previews duplicate options',
    (tester) async {
      String? copiedCode;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedCode = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await start(tester);
      await tester.tap(find.text('Nhập / Xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã chia sẻ · 2 combo'));
      await tester.pumpAndSettle();
      expect(find.text('Sao chép mã đầy đủ'), findsOneWidget);
      await tester.tap(find.text('Sao chép mã đầy đủ'));
      await tester.pumpAndSettle();
      final code = copiedCode!;
      expect(code, startsWith('TRON1.'));
      await tester.tap(find.text('Nhập'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), code);
      await tester.tap(find.text('Xem trước combo'));
      await tester.pumpAndSettle();
      expect(find.text('2 combo trong gói'), findsOneWidget);
      await tester.ensureVisible(find.text('Tạo bản sao'));
      await tester.tap(find.text('Tạo bản sao'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xác nhận nhập · 2 combo'));
      await tester.tap(find.text('Xác nhận nhập · 2 combo'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TronApp)),
      );
      expect((await container.read(comboListProvider.future)).length, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Three primary screens render without overflow on compact devices',
    (tester) async {
      await start(tester, size: const Size(320, 640), textScale: 1.15);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('+ Tạo combo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhập / Xuất'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Scheduled call opens, answers and ends', (tester) async {
    await start(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TronApp)),
    );
    final combo = (await container.read(comboListProvider.future)).first;
    container.read(callProvider.notifier).schedule(combo, Duration.zero);
    // Màn Zalo có vòng sáng lặp vô hạn nên không dùng pumpAndSettle ở đây.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cuộc gọi thoại đến…'), findsOneWidget);
    await tester.tap(find.text('Trả lời'));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(callProvider).status, CallStatus.inProgress);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(container.read(callProvider).status, CallStatus.idle);
    expect(find.text('Cần lối thoát?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Primary screen visual snapshots', (tester) async {
    await start(tester);
    await expectLater(
      find.byKey(const ValueKey('app-preview')),
      matchesGoldenFile('goldens/home_dark.png'),
    );
    await tester.tap(find.text('+ Tạo combo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Sếp gọi gấp');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('app-preview')),
      matchesGoldenFile('goldens/combo_form_dark.png'),
    );
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập / Xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo mã chia sẻ · 2 combo'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('app-preview')),
      matchesGoldenFile('goldens/sharing_dark.png'),
    );
  });
}
