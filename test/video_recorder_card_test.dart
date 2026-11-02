import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/video_recorder.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/widgets/call_type_selector.dart';
import 'package:tron/features/combo/widgets/video_recorder_card.dart';
import 'package:tron/shared/enums/call_interface.dart';

/// Chọn file luôn trả về một video có sẵn, không mở hộp thoại hệ thống.
class PickedVideoFiles extends FileService {
  @override
  Future<String?> pickVideo() async => 'media:0f0f.mp4';
}

void main() {
  Future<List<String?>> pump(
    WidgetTester tester, {
    String? videoPath,
    VideoRecordLauncher? launchRecorder,
  }) async {
    final changes = <String?>[];
    String? current = videoPath;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileServiceProvider.overrideWithValue(PickedVideoFiles()),
          // Video chọn từ máy dài 30 giây, trong giới hạn.
          videoRecorderProvider.overrideWithValue(
            VideoRecorder(
              PickedVideoFiles(),
              probeDuration: (_) async => const Duration(seconds: 30),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => VideoRecorderCard(
                videoPath: current,
                onChanged: (path) {
                  changes.add(path);
                  setState(() => current = path);
                },
                onBusyChanged: (_) {},
                launchRecorder: launchRecorder ?? (_) async => null,
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('Without a video the caller looks like the camera is off', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Video người gọi'), findsOneWidget);
    expect(find.textContaining('tắt camera'), findsOneWidget);
  });

  testWidgets('Picking an MP4 file sets the caller video', (tester) async {
    final changes = await pump(tester);
    await tester.tap(find.byTooltip('Chọn video MP4 có sẵn'));
    await tester.pumpAndSettle();
    expect(changes, ['media:0f0f.mp4']);
    expect(find.text('Video tự quay'), findsOneWidget);
  });

  testWidgets('Recording sets the new video; cancelling changes nothing', (
    tester,
  ) async {
    String? result;
    final changes = await pump(tester, launchRecorder: (_) async => result);
    // Máy test giả lập Android nên có nút quay.
    await tester.tap(find.text('Quay'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    result = 'media:1111.mp4';
    await tester.tap(find.text('Quay'));
    await tester.pumpAndSettle();
    expect(changes, ['media:1111.mp4']);
    await tester.tap(find.byTooltip('Xoá video'));
    await tester.pump();
    expect(changes, ['media:1111.mp4', null]);
  });

  testWidgets('Call type selector switches between voice and video', (
    tester,
  ) async {
    var selected = CallType.voice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CallTypeSelector(
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Gọi video'));
    await tester.pump();
    expect(selected, CallType.video);
  });

  test('Call type and video survive save and load', () {
    final combo = ComboModel(
      id: 'c',
      name: 'Sếp',
      scenarioId: 'boss',
      callInterface: CallInterface.zalo,
      createdAt: DateTime(2026),
      callType: CallType.video,
      videoPath: 'media:0f0f.mp4',
      videoMediaId: 'aaaaaaaa-0000-0000-0000-000000000001',
    );
    final restored = ComboModel.fromJson(combo.toJson());
    expect(restored.callType, CallType.video);
    expect(restored.videoPath, 'media:0f0f.mp4');
    expect(restored.videoMediaId, combo.videoMediaId);
    expect(combo.customMediaPaths, ['media:0f0f.mp4']);
    expect(combo.withoutSync().videoMediaId, isNull);
    expect(combo.copyWith(stripCustomAudio: true).videoPath, isNull);
    expect(combo.sameContentAs(combo.withoutSync()), isTrue);
    // Dữ liệu từ bản app cũ không có loại cuộc gọi: mặc định gọi thoại.
    final legacy = ComboModel.fromJson(
      combo.toJson()
        ..remove('callType')
        ..remove('videoPath'),
    );
    expect(legacy.callType, CallType.voice);
    expect(legacy.videoPath, isNull);
  });
}
