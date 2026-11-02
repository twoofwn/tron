import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/constants/app_constants.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/video_recorder.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/widgets/video_recorder_card.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/sharing/repositories/sharing_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

/// File riêng trong bộ nhớ với dung lượng tuỳ chỉnh, không cần đọc file thật.
class SizedFiles extends FileService {
  SizedFiles(this.sizes);
  final Map<String, int> sizes;
  final deleted = <String>[];
  @override
  Future<int> mediaSize(String path) async => sizes[path] ?? 0;
  @override
  Future<Uint8List> readMedia(String path) async =>
      throw StateError('Không được đọc file khi gói đã quá lớn.');
  @override
  Future<String?> pickVideo() async => 'media:0f0f.mp4';
  @override
  Future<void> deleteAudio(String path) async => deleted.add(path);
}

void main() {
  const mb = 1024 * 1024;

  test('Sizes and durations read naturally in Vietnamese', () {
    expect(sizeLabel(10 * mb), '10 MB');
    expect(sizeLabel((14.2 * mb).round()), '14,2 MB');
    expect(sizeLabel(850 * 1024), '850 KB');
    expect(durationLabel(const Duration(seconds: 45)), '45 giây');
    expect(durationLabel(const Duration(seconds: 85)), '1:25');
  });

  test('Too large and empty files are explained with the real size', () {
    expect(
      () => FileService.ensureSize(
        (14.2 * mb).round(),
        limit: 10 * mb,
        what: 'File MP3',
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'File MP3 nặng 14,2 MB, vượt giới hạn 10 MB. Hãy chọn file nhỏ hơn.',
        ),
      ),
    );
    expect(
      () => FileService.ensureSize(0, limit: 10 * mb, what: 'File MP3'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('trống'),
        ),
      ),
    );
    FileService.ensureSize(10 * mb, limit: 10 * mb, what: 'File MP3');
  });

  group('Picked caller video length', () {
    VideoRecorder recorder(SizedFiles files, Duration? length) =>
        VideoRecorder(files, probeDuration: (_) async => length);

    // Chỉ giới hạn dung lượng: video dài hay ngắn đều nhận nếu phát được.
    for (final length in [
      const Duration(milliseconds: 400),
      const Duration(seconds: 42),
      const Duration(minutes: 5),
    ]) {
      test('A playable video of $length is accepted', () async {
        final files = SizedFiles({});
        final path = await recorder(
          files,
          length,
        ).checkPickedVideo('media:0f0f.mp4');
        expect(path, 'media:0f0f.mp4');
        expect(files.deleted, isEmpty);
      });
    }

    for (final (length, message) in [
      (Duration.zero, 'Không đọc được video'),
      (null, 'Không đọc được video'),
    ]) {
      test('Rejects $length and deletes the imported copy', () async {
        final files = SizedFiles({});
        await expectLater(
          recorder(files, length).checkPickedVideo('media:0f0f.mp4'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(message),
            ),
          ),
        );
        expect(files.deleted, ['media:0f0f.mp4']);
      });
    }
  });

  testWidgets('The video card tells why a picked video was refused', (
    tester,
  ) async {
    final files = SizedFiles({});
    final changes = <String?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileServiceProvider.overrideWithValue(files),
          videoRecorderProvider.overrideWithValue(
            VideoRecorder(files, probeDuration: (_) async => null),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoRecorderCard(
              videoPath: null,
              onChanged: changes.add,
              onBusyChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Chọn video MP4 có sẵn'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.textContaining('Không đọc được video'), findsOneWidget);
  });

  test('Recording stops on size, not length (about 2 minutes for 20 MB)', () {
    final stop = VideoRecorder.autoStopAfter;
    expect(stop, greaterThan(const Duration(seconds: 60)));
    expect(
      VideoRecorder.estimatedBytes(stop),
      lessThan(AppConstants.maxVideoBytes),
    );
  });

  group('Share package size', () {
    final combo = ComboModel(
      id: 'c',
      name: 'Sếp',
      scenarioId: 'boss',
      callInterface: CallInterface.zalo,
      createdAt: DateTime(2026),
      callType: CallType.video,
      videoPath: 'media:0f0f.mp4',
    );

    test('An oversized package is refused before any file is read', () async {
      final sharing = SharingRepository(
        SizedFiles({'media:0f0f.mp4': 20 * mb}),
      );
      final copy = combo.copyWith(id: 'd', videoPath: 'media:1111.mp4');
      final files = SizedFiles({
        'media:0f0f.mp4': 20 * mb,
        'media:1111.mp4': 20 * mb,
      });
      expect(
        await SharingRepository(files)
            .estimateSize([combo, copy], includeAudio: true),
        greaterThan(AppConstants.maxPackageBytes),
      );
      await expectLater(
        SharingRepository(files).create([combo, copy], includeAudio: true),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Gói nặng khoảng'), contains('vượt giới hạn 25 MB')),
          ),
        ),
      );
      // Không kèm âm thanh thì gói chỉ còn vài KB.
      expect(
        await sharing.estimateSize([combo], includeAudio: false),
        lessThan(mb),
      );
    });

    test('A pasted code that is far too long says so', () {
      final sharing = SharingRepository(SizedFiles({}));
      expect(
        () => sharing.decodeCode('TRON1.${'A' * (40 * mb)}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Mã chia sẻ quá dài'),
          ),
        ),
      );
    });
  });

  test('Scenario audio over 10 MB is refused with its size', () async {
    final repository = ScenarioRepository();
    await expectLater(
      repository.importAudio(Uint8List(11 * mb), 'loi-thoai.mp3'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'File “loi-thoai.mp3” nặng 11 MB, vượt giới hạn 10 MB. '
              'Hãy chọn file nhỏ hơn.',
        ),
      ),
    );
    await expectLater(
      repository.importAudio(Uint8List(10), 'video.mp4'),
      throwsA(isA<FormatException>()),
    );
  });
}
