import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/app/app.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/background_preview.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/video_recorder.dart';
import 'package:tron/features/activation/providers/activation_provider.dart';
import 'package:tron/features/activation/services/permission_service.dart';
import 'package:tron/features/backup/services/backup_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/providers/combo_provider.dart';
import 'package:tron/features/fake_call/models/call_script.dart';
import 'package:tron/features/fake_call/services/call_script_runner.dart';
import 'package:tron/features/fake_call/services/reply_listener.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/features/fake_call/screens/fake_call_screen.dart';
import 'package:tron/features/fake_call/services/call_device_service.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/scenarios/providers/scenario_provider.dart';
import 'package:tron/features/settings/providers/settings_provider.dart';
import 'package:tron/shared/enums/call_interface.dart';
import 'package:tron/features/sharing/repositories/sharing_repository.dart';

import 'core/fake_background_loop.dart';
import 'features/fake_call/fake_reply_listener.dart';

class NoDeepLinks implements DeepLinkSource {
  @override
  Stream<Uri> get uris => const Stream<Uri>.empty();

  @override
  Future<Uri?> initialUri() async => null;
}

class SilentAudioService extends AudioService {
  SilentAudioService() : super(FileService());
  @override
  Future<void> stop() async {}
  @override
  Future<void> ring(
    ComboModel combo, {
    PhoneStyle phoneStyle = PhoneStyle.samsung,
  }) async {}
  @override
  Future<void> conversation(
    ComboModel combo,
    CallScript script, {
    bool withVoice = true,
    ReplyWaiter? waitForReply,
    double backgroundVolume = AppSettings.defaultBackgroundVolume,
  }) async {}
  @override
  Future<void> speak(String dialogue) async {}
  @override
  Future<void> prepareSpeech(CallScript script) async {}
  @override
  void dispose() {}
}

/// Chọn video luôn trả về một file có sẵn, không mở hộp thoại hệ thống.
class PickedVideoFiles extends FileService {
  @override
  Future<String?> pickVideo() async => 'media:0f0f.mp4';
}

/// Server tạo mã ngắn `EH-` giả: trả về khi `reply` hoàn tất, không gọi mạng.
class FakeOnlineShare extends BackupService {
  FakeOnlineShare(super.ref, this.reply);
  final Future<String> Function() reply;
  @override
  Future<String> createOnlineShare(
    List<ComboModel> selectedCombos, {
    List<Scenario> selectedScenarios = const [],
    required bool includeAudio,
  }) => reply();
}

/// Kênh Android thật không trả lời trong test, nên thay bằng bản không làm gì.
class SilentCallDevice extends CallDeviceService {
  SilentCallDevice() : super(const MethodChannel('test/call'));
  @override
  Future<void> setSilenceKeys(bool enabled) async {}
  @override
  Future<void> startCallAudio({required bool speaker}) async {}
  @override
  Future<void> setSpeaker(bool on) async {}
  @override
  Future<void> endCallAudio() async {}
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
    List<Override> overrides = const [],
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
          callDeviceServiceProvider.overrideWithValue(SilentCallDevice()),
          replyListenerProvider.overrideWithValue(FakeReplyListener()),
          deepLinkSourceProvider.overrideWithValue(NoDeepLinks()),
          // Quyền thật phụ thuộc máy; cố định để giao diện và golden ổn định.
          permissionSnapshotProvider.overrideWith(
            (ref) => Future.value(
              const PermissionSnapshot(
                notifications: true,
                exactAlarm: true,
                batteryUnrestricted: true,
              ),
            ),
          ),
          sharingRepositoryProvider.overrideWith(
            (ref) => SharingRepository(
              ref.watch(fileServiceProvider),
              createId: () => '7c2a1000-0000-4000-a000-000000000000',
            ),
          ),
          ...overrides,
        ],
        child: const RepaintBoundary(
          key: ValueKey('app-preview'),
          child: TronApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Kho kịch bản thật đọc file, không tải xong trong thời gian giả của
  /// testWidgets nên màn Xuất chờ mãi. Combo mặc định dùng kịch bản có sẵn,
  /// nên test chia sẻ chỉ cần một kho rỗng.
  final emptyScenarioLibrary = scenarioLibraryProvider.overrideWith(
    (ref) async => ScenarioRepository(),
  );

  testWidgets('Home selection, timer changes, cancellation and theme switch', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('COMBO CỦA BẠN'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    final themeSwitch = find.widgetWithText(SwitchListTile, 'Giao diện sáng');
    tester.view.physicalSize = const Size(390, 2400);
    await tester.pumpAndSettle();
    await tester.tap(themeSwitch);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Cài đặt'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Video combo asks for a caller name instead of a scenario', (
    tester,
  ) async {
    await start(
      tester,
      overrides: [
        fileServiceProvider.overrideWithValue(PickedVideoFiles()),
        videoRecorderProvider.overrideWithValue(
          VideoRecorder(
            PickedVideoFiles(),
            probeDuration: (_) async => const Duration(seconds: 30),
          ),
        ),
      ],
    );
    await tester.tap(find.text('Tạo combo'));
    await tester.pumpAndSettle();
    expect(find.text('Tên người gọi'), findsNothing);
    await tester.tap(find.text('Gọi video'));
    await tester.pumpAndSettle();
    // Gọi video: không chọn kịch bản, không âm nền; chỉ cần tên người gọi.
    expect(find.text('Tên người gọi'), findsOneWidget);
    expect(find.text('Kịch bản', skipOffstage: false), findsNothing);
    expect(
      find.text('Âm nền & nhạc nền trong cuộc gọi', skipOffstage: false),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('Khi video kết thúc'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lặp lại video'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tên combo'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextFormField).first, 'Mẹ gọi video');
    await tester.tap(find.text('Lưu combo'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên hiện trên cuộc gọi video'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'Mẹ');
    await tester.tap(find.text('Lưu combo'));
    await tester.pump();
    // Không có kịch bản thoại thì phải có video.
    expect(find.text('Hãy quay hoặc chọn video người gọi.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text('Lưu combo')))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Chọn video MP4 có sẵn'));
    await tester.tap(find.byTooltip('Chọn video MP4 có sẵn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu combo'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TronApp)),
    );
    final saved = (await container.read(comboListProvider.future))
        .firstWhere((combo) => combo.name == 'Mẹ gọi video');
    expect(saved.callType, CallType.video);
    expect(saved.callerName, 'Mẹ');
    expect(saved.videoPath, 'media:0f0f.mp4');
    expect(find.text('Mẹ gọi video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Form validates, creates a combo and persists it', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Tạo combo'));
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

  testWidgets('Background sounds can be previewed and their volume saved', (
    tester,
  ) async {
    final loops = LoopFactory();
    await start(
      tester,
      size: const Size(390, 2400),
      overrides: [backgroundPreviewLoopProvider.overrideWithValue(loops.call)],
    );
    await tester.tap(find.text('Tạo combo'));
    await tester.pumpAndSettle();
    // Chưa chọn âm nền thì chưa nghe thử được.
    expect(find.text('Chọn ít nhất một âm nền để nghe thử.'), findsOneWidget);
    await tester.tap(find.text('Nghe thử âm nền'));
    await tester.pump();
    expect(loops.loops, isEmpty);

    await tester.tap(find.text('Còi xe'));
    await tester.pump();
    await tester.tap(find.text('Nghe thử âm nền'));
    await tester.pumpAndSettle();
    expect(find.text('Dừng nghe thử'), findsOneWidget);
    expect(loops.loops.single.source, 'traffic');
    expect(loops.loops.single.volume, AppSettings.defaultBackgroundVolume);

    // Đổi lựa chọn khi đang nghe thì nghe ngay danh sách mới.
    await tester.tap(find.text('Trời mưa'));
    await tester.pumpAndSettle();
    final playing = loops.loops.where((loop) => !loop.disposed);
    expect(playing.map((loop) => loop.source), ['traffic', 'rain']);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.3);
    slider.onChangeEnd!(0.3);
    await tester.pumpAndSettle();
    expect(playing.map((loop) => loop.volume), everyElement(0.3));
    expect(find.text('30%'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TronApp)),
    );
    expect(
      (await container.read(settingsProvider.future)).backgroundVolume,
      0.3,
    );

    // Gọi video không có âm nền: nghe thử dừng.
    await tester.tap(find.text('Gọi video'));
    await tester.pumpAndSettle();
    expect(loops.loops.every((loop) => loop.disposed), isTrue);
    expect(container.read(backgroundPreviewProvider), isFalse);
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
      // Server không trả lời được: mã offline vẫn dùng ngay.
      await start(
        tester,
        overrides: [
          emptyScenarioLibrary,
          backupServiceProvider.overrideWith(
            (ref) => FakeOnlineShare(
              ref,
              () => Future.error(const FormatException('offline')),
            ),
          ),
        ],
      );
      await tester.tap(find.text('Nhập / Xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã chia sẻ · 2 combo'));
      await tester.pumpAndSettle();
      expect(find.text('Sao chép mã đầy đủ'), findsOneWidget);
      expect(find.textContaining('Chưa lấy được mã ngắn EH-'), findsOneWidget);
      expect(find.textContaining('Sao chép mã EH-'), findsNothing);
      await tester.tap(find.text('Sao chép mã đầy đủ'));
      await tester.pumpAndSettle();
      final code = copiedCode!;
      expect(code, startsWith('TRON1.'));
      await tester.tap(find.text('Nhập'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), code);
      await tester.tap(find.text('Xem trước gói chia sẻ'));
      await tester.pumpAndSettle();
      expect(find.text('2 combo trong gói'), findsOneWidget);
      await tester.ensureVisible(find.text('Tạo bản sao'));
      await tester.tap(find.text('Tạo bản sao'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xác nhận nhập · 2 mục'));
      await tester.tap(find.text('Xác nhận nhập · 2 mục'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TronApp)),
      );
      expect((await container.read(comboListProvider.future)).length, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Offline code shows at once, short EH- code arrives later', (
    tester,
  ) async {
    final server = Completer<String>();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await start(
      tester,
      overrides: [
        emptyScenarioLibrary,
        backupServiceProvider.overrideWith(
          (ref) => FakeOnlineShare(ref, () => server.future),
        ),
      ],
    );
    await tester.tap(find.text('Nhập / Xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo mã chia sẻ · 2 combo'));
    await tester.pumpAndSettle();

    // Server chưa trả lời: QR và mã đầy đủ đã có.
    expect(find.textContaining('Đang lấy mã ngắn EH-'), findsOneWidget);
    await tester.tap(find.text('Sao chép mã đầy đủ'));
    await tester.pumpAndSettle();
    final fullBefore = copied;
    expect(fullBefore, startsWith('TRON1.'));

    server.complete('EH-ABC123');
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang lấy mã ngắn EH-'), findsNothing);
    expect(find.text('Sao chép mã EH-ABC123'), findsOneWidget);
    // Mã đầy đủ không đổi khi mã ngắn về.
    await tester.tap(find.text('Sao chép mã đầy đủ'));
    await tester.pumpAndSettle();
    expect(copied, fullBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Three primary screens render without overflow on compact devices',
    (tester) async {
      await start(tester, size: const Size(320, 640), textScale: 1.15);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tạo combo'));
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
    expect(find.text('Cuộc gọi thoại đến'), findsOneWidget);
    await tester.tap(find.text('Trả lời'));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(callProvider).status, CallStatus.inProgress);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Cuộc gọi kết thúc'), findsOneWidget);
    // Màn gọi giữ dòng "Cuộc gọi kết thúc" giây lát rồi mới đóng.
    await tester.pump(FakeCallScreen.endedHold);
    // Máy test không đưa app ra nền được: màn gọi tự đóng về trang chủ.
    // Câu trả lời của kênh nền tảng về theo thời gian thật nên chờ bằng runAsync.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(container.read(callProvider).status, CallStatus.idle);
    expect(find.text('COMBO CỦA BẠN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Primary screen visual snapshots', (tester) async {
    await start(tester);
    await expectLater(
      find.byKey(const ValueKey('app-preview')),
      matchesGoldenFile('goldens/home_dark.png'),
    );
    await tester.tap(find.text('Tạo combo'));
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
