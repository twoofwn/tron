import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/app/providers/app_foreground_provider.dart';
import 'package:tron/core/constants/built_in_ringtone.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/video_recorder.dart';
import 'package:tron/features/activation/services/call_alarm_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/features/fake_call/screens/fake_call_screen.dart';
import 'package:tron/features/fake_call/services/call_device_service.dart';
import 'package:tron/features/fake_call/widgets/video_in_call_view.dart';
import 'package:tron/features/settings/models/app_settings.dart';
import 'package:tron/features/settings/providers/settings_provider.dart';
import 'package:tron/shared/enums/call_interface.dart';

class CountingAlarm extends CallAlarmService {
  int cancelled = 0;
  @override
  Future<bool> scheduleCall({
    required String comboId,
    required DateTime fireAt,
    required BuiltInRingtone ringtone,
  }) async => true;
  @override
  Future<void> cancel() async => cancelled++;
}

class RecordingAudioService extends AudioService {
  RecordingAudioService() : super(FileService());
  final events = <String>[];
  final phoneStyles = <PhoneStyle>[];
  @override
  Future<void> stop() async => events.add('stop');
  @override
  Future<void> ring(
    ComboModel combo, {
    PhoneStyle phoneStyle = PhoneStyle.samsung,
  }) async {
    phoneStyles.add(phoneStyle);
    events.add('ring:${combo.callInterface.name}');
  }

  @override
  Future<void> conversation(
    ComboModel combo,
    String dialogue, {
    bool withVoice = true,
  }) async => events.add(withVoice ? 'conversation' : 'conversation:silent');
  final preparedSpeech = <String>[];
  @override
  Future<void> prepareSpeech(String dialogue) async =>
      preparedSpeech.add(dialogue);
  @override
  void dispose() {}
}

/// Video người gọi không mở được (file hỏng hoặc bị xoá).
class BrokenVideoFiles extends FileService {
  @override
  Future<String> videoLocation(String path) async =>
      throw StateError('Không có video.');
}

class FakeCallDevice extends CallDeviceService {
  FakeCallDevice() : super(const MethodChannel('test/call'));
  final calls = <String>[];
  final _keys = StreamController<void>.broadcast();
  void pressVolumeKey() => _keys.add(null);
  @override
  Stream<void> get volumeKeyPresses => _keys.stream;
  @override
  Future<void> setSilenceKeys(bool enabled) async =>
      calls.add('silenceKeys:$enabled');
  @override
  Future<void> startCallAudio({required bool speaker}) async =>
      calls.add('start:$speaker');
  @override
  Future<void> setSpeaker(bool on) async => calls.add('speaker:$on');
  @override
  Future<void> endCallAudio() async => calls.add('end');
}

void main() {
  Future<RecordingAudioService> open(
    WidgetTester tester,
    CallInterface callInterface, {
    Size size = const Size(390, 844),
    double textScale = 1,
    CallType callType = CallType.voice,
    String? videoPath,
    String? callerName,
    FakeCallDevice? device,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final audio = RecordingAudioService();
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey(callInterface),
        overrides: [
          audioServiceProvider.overrideWithValue(audio),
          fileServiceProvider.overrideWithValue(BrokenVideoFiles()),
          // Máy test không có camera: khung camera của mình hiện như đang tắt.
          videoRecorderProvider.overrideWithValue(
            VideoRecorder(FileService(), listCameras: () async => const []),
          ),
          callDeviceServiceProvider.overrideWithValue(
            device ?? FakeCallDevice(),
          ),
          resolvedPhoneStyleProvider.overrideWith(
            (ref) async => PhoneStyle.iphone,
          ),
        ],
        child: MaterialApp(
          home: FakeCallScreen(
            arguments: FakeCallArguments(
              ComboModel(
                id: 'c',
                name: 'Combo',
                scenarioId: 'boss',
                callInterface: callInterface,
                createdAt: DateTime(2026),
                callType: callType,
                videoPath: videoPath,
                callerName: callerName,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return audio;
  }

  for (final callInterface in CallInterface.values) {
    testWidgets('${callInterface.name} rings, answers and ends', (
      tester,
    ) async {
      final audio = await open(tester, callInterface);
      expect(audio.events, ['ring:${callInterface.name}']);
      expect(find.text('Anh Minh · Công việc'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
      expect(find.text('tắt tiếng'), findsOneWidget);
      expect(audio.events.last, 'conversation');
      // Tắt tiếng chỉ đổi trạng thái, không dừng hội thoại.
      await tester.tap(find.text('tắt tiếng'));
      await tester.pump();
      expect(audio.events.last, 'conversation');
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump();
      expect(audio.events.last, 'stop');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Call screens fit a compact device with large text', (
    tester,
  ) async {
    for (final callInterface in CallInterface.values) {
      await open(
        tester,
        callInterface,
        size: const Size(320, 640),
        textScale: 1.15,
      );
      expect(tester.takeException(), isNull, reason: callInterface.name);
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
      expect(tester.takeException(), isNull, reason: callInterface.name);
    }
  });

  testWidgets('A volume key silences the ringing but keeps the call', (
    tester,
  ) async {
    final device = FakeCallDevice();
    final audio = await open(tester, CallInterface.phone, device: device);
    expect(device.calls, ['silenceKeys:true']);
    expect(audio.events, ['ring:phone']);
    expect(audio.preparedSpeech, hasLength(1));

    device.pressVolumeKey();
    await tester.pump();
    expect(audio.events, ['ring:phone', 'stop']);
    // Bấm thêm lần nữa không làm gì.
    device.pressVolumeKey();
    await tester.pump();
    expect(audio.events, ['ring:phone', 'stop']);
    expect(find.text('Trả lời'), findsOneWidget);

    await tester.tap(find.text('Trả lời'));
    await tester.pump();
    expect(audio.events.last, 'conversation');
    expect(device.calls, [
      'silenceKeys:true',
      'silenceKeys:false',
      'start:false',
    ]);
  });

  testWidgets('The speaker button switches between earpiece and speaker', (
    tester,
  ) async {
    final device = FakeCallDevice();
    await open(tester, CallInterface.zalo, device: device);
    await tester.tap(find.text('Trả lời'));
    await tester.pump();
    expect(device.calls.last, 'start:false');

    await tester.tap(find.text('loa'));
    await tester.pump();
    expect(device.calls.last, 'speaker:true');
    await tester.tap(find.text('loa'));
    await tester.pump();
    expect(device.calls.last, 'speaker:false');

    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump();
    // Kết thúc cuộc gọi thì trả âm thanh của máy về bình thường.
    expect(device.calls.last, 'end');
  });

  testWidgets('Declining before answering leaves call audio untouched', (
    tester,
  ) async {
    final device = FakeCallDevice();
    await open(tester, CallInterface.messenger, device: device);
    await tester.tap(find.text('Nhắn tin'));
    await tester.pump();
    expect(device.calls, isNot(contains('end')));
    expect(device.calls.last, 'silenceKeys:false');
  });

  testWidgets('Ringtone follows the phone style from settings', (tester) async {
    final audio = await open(tester, CallInterface.phone);
    expect(audio.phoneStyles, [PhoneStyle.iphone]);
  });

  testWidgets('Locked phone lets the notification ring until the app opens', (
    tester,
  ) async {
    final audio = RecordingAudioService();
    final alarm = CountingAlarm();
    final container = ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWithValue(audio),
        callAlarmServiceProvider.overrideWithValue(alarm),
        callDeviceServiceProvider.overrideWithValue(FakeCallDevice()),
        resolvedPhoneStyleProvider.overrideWith(
          (ref) async => PhoneStyle.huawei,
        ),
      ],
    );
    addTearDown(container.dispose);
    final combo = ComboModel(
      id: 'c',
      name: 'Combo',
      scenarioId: 'boss',
      callInterface: CallInterface.phone,
      createdAt: DateTime(2026),
    );
    container.read(appForegroundProvider.notifier).setForeground(false);
    container.read(callProvider.notifier).ringNow(combo);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: FakeCallScreen(
            arguments: FakeCallArguments(combo, isPreview: false),
          ),
        ),
      ),
    );
    await tester.pump();
    // Chỉ thông báo hệ thống đổ chuông, app chưa phát gì.
    expect(audio.events, isEmpty);
    final cancelledBefore = alarm.cancelled;

    container.read(appForegroundProvider.notifier).setForeground(true);
    await tester.pump();
    await tester.pump();
    expect(audio.events, ['ring:phone']);
    expect(audio.phoneStyles, [PhoneStyle.huawei]);
    // Thông báo bị tắt để không phát chồng hai chuông.
    expect(alarm.cancelled, greaterThan(cancelledBefore));
  });

  testWidgets('Phone and Messenger message buttons decline the call', (
    tester,
  ) async {
    for (final (callInterface, label) in [
      (CallInterface.phone, 'Tin nhắn'),
      (CallInterface.messenger, 'Nhắn tin'),
    ]) {
      final audio = await open(tester, callInterface);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(audio.events.last, 'stop', reason: callInterface.name);
    }
  });

  for (final (callInterface, ringing) in [
    (CallInterface.phone, 'cuộc gọi video'),
    (CallInterface.zalo, 'Cuộc gọi video đến…'),
    (CallInterface.messenger, 'đang gọi video cho bạn…'),
  ]) {
    testWidgets('${callInterface.name} video call without video shows avatar', (
      tester,
    ) async {
      final audio = await open(
        tester,
        callInterface,
        callType: CallType.video,
        callerName: 'Mẹ yêu',
      );
      expect(find.text(ringing), findsOneWidget);
      // Gọi video dùng tên người gọi của combo, không dùng kịch bản.
      expect(find.textContaining('Mẹ yêu'), findsWidgets);
      expect(find.textContaining('Anh Minh'), findsNothing);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      await tester.pump();
      // Người gọi "tắt camera"; gọi video không có thoại nên không phát giọng.
      expect(find.byType(VideoInCallView), findsOneWidget);
      expect(find.text('Mẹ yêu'), findsOneWidget);
      expect(find.text('Camera đang tắt'), findsOneWidget);
      expect(find.text('tắt camera'), findsOneWidget);
      expect(audio.events.last, 'conversation:silent');
      await tester.tap(find.text('tắt camera'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump();
      expect(audio.events.last, 'stop');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Video that cannot play shows the avatar without a voice', (
    tester,
  ) async {
    final audio = await open(
      tester,
      CallInterface.messenger,
      callType: CallType.video,
      videoPath: 'media:0f0f.mp4',
    );
    await tester.tap(find.text('Trả lời'));
    await tester.pump();
    // Có video: không phát âm nền hay giọng, tiếng nằm trong video.
    expect(audio.events, contains('conversation:silent'));
    // Video không mở được: báo lỗi, không phát giọng kịch bản.
    await tester.pump();
    await tester.pump();
    expect(audio.events.last, 'conversation:silent');
    expect(audio.events, isNot(contains('conversation')));
    expect(find.text('Camera đang tắt'), findsOneWidget);
    expect(
      find.text('Không phát được video người gọi trên thiết bị này.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('The self view can be dragged and snaps to a corner', (
    tester,
  ) async {
    await open(tester, CallInterface.zalo, callType: CallType.video);
    await tester.tap(find.text('Trả lời'));
    await tester.pump();
    final self = find.bySemanticsLabel('Camera của bạn đang tắt');
    final start = tester.getTopLeft(self);
    // Mặc định ở góc trên phải.
    expect(start.dx, greaterThan(390 / 2));
    await tester.drag(self, const Offset(-300, 400));
    await tester.pumpAndSettle();
    final end = tester.getTopLeft(self);
    // Thả gần góc dưới trái thì dính vào góc đó, vẫn nằm trên hàng nút.
    expect(end.dx, lessThan(390 / 2));
    expect(end.dy, greaterThan(start.dy));
    expect(end.dy + 152, lessThanOrEqualTo(844 - 130));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Video call screen fits a compact device with large text', (
    tester,
  ) async {
    await open(
      tester,
      CallInterface.zalo,
      size: const Size(320, 640),
      textScale: 1.3,
      callType: CallType.video,
    );
    await tester.tap(find.text('Trả lời'));
    await tester.pump();
    expect(find.byType(VideoInCallView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
