import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/audio_service.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/video_recorder.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/screens/fake_call_screen.dart';
import 'package:tron/features/fake_call/widgets/video_in_call_view.dart';
import 'package:tron/shared/enums/call_interface.dart';

class RecordingAudioService extends AudioService {
  RecordingAudioService() : super(FileService());
  final events = <String>[];
  @override
  Future<void> stop() async => events.add('stop');
  @override
  Future<void> ring(ComboModel combo) async =>
      events.add('ring:${combo.callInterface.name}');
  @override
  Future<void> conversation(
    ComboModel combo,
    String dialogue, {
    bool withVoice = true,
  }) async => events.add(withVoice ? 'conversation' : 'conversation:silent');
  @override
  void dispose() {}
}

/// Video người gọi không mở được (file hỏng hoặc bị xoá).
class BrokenVideoFiles extends FileService {
  @override
  Future<String> videoLocation(String path) async =>
      throw StateError('Không có video.');
}

void main() {
  Future<RecordingAudioService> open(
    WidgetTester tester,
    CallInterface callInterface, {
    Size size = const Size(390, 844),
    double textScale = 1,
    CallType callType = CallType.voice,
    String? videoPath,
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
      final audio = await open(tester, callInterface, callType: CallType.video);
      expect(find.text(ringing), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      await tester.tap(find.text('Trả lời'));
      await tester.pump();
      await tester.pump();
      // Người gọi "tắt camera": phát giọng như gọi thoại.
      expect(find.byType(VideoInCallView), findsOneWidget);
      expect(find.text('Camera đang tắt'), findsOneWidget);
      expect(find.text('tắt camera'), findsOneWidget);
      expect(audio.events.last, 'conversation');
      await tester.tap(find.text('tắt camera'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump();
      expect(audio.events.last, 'stop');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Video that cannot play falls back to the voice', (tester) async {
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
    // Video không mở được → quay về giọng.
    await tester.pump();
    await tester.pump();
    expect(audio.events.last, 'conversation');
    expect(find.text('Camera đang tắt'), findsOneWidget);
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
