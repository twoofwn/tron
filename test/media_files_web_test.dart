@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/services/media_files_web.dart';

void main() {
  test(
    'Video larger than localStorage quota is stored and read back',
    () async {
      // localStorage chỉ khoảng 5 MB; video 8 MB phải lưu được trong IndexedDB.
      final video = Uint8List.fromList(
        List.generate(8 * 1024 * 1024, (i) => i % 251),
      );
      await writeMediaFile('big.mp4', video);
      expect(await mediaFileExists('big.mp4'), isTrue);
      expect(await mediaFileSize('big.mp4'), video.length);
      expect(await readMediaFile('big.mp4'), video);
      // Sau khi có video lớn, dữ liệu combo trong localStorage vẫn lưu được.
      final prefs = await SharedPreferences.getInstance();
      expect(await prefs.setString('tron.combos.test', 'x' * 100000), isTrue);
      await deleteMediaFile('big.mp4');
      expect(await mediaFileExists('big.mp4'), isFalse);
      await expectLater(readMediaFile('big.mp4'), throwsStateError);
    },
  );

  test('Files saved by the old version move out of localStorage', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    SharedPreferences.setMockInitialValues({
      'tron.audio.old.wav': base64Encode(bytes),
    });
    expect(await mediaFileExists('old.wav'), isTrue);
    expect(await readMediaFile('old.wav'), bytes);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('tron.audio.old.wav'), isFalse);
    expect(await readMediaFile('old.wav'), bytes);
    await deleteMediaFile('old.wav');
  });
}
