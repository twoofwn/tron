import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_files.dart' as media;

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

class StorageService {
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  /// Ghi dữ liệu; lỗi (trên web thường do localStorage đầy) thì báo lỗi thật,
  /// không để bộ nhớ đệm giữ giá trị chưa lưu làm app tưởng đã lưu được.
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (await prefs.setString(key, value)) {
        return;
      }
    } catch (_) {
      // Thử dọn chỗ rồi ghi lại một lần.
    }
    try {
      // Web: file âm thanh/video kiểu cũ chiếm localStorage, chuyển sang IndexedDB.
      await media.releaseLegacyMediaStorage();
      if (await prefs.setString(key, value)) {
        return;
      }
    } catch (_) {
      // Vẫn không ghi được: báo lỗi bên dưới.
    }
    // Bỏ giá trị chưa lưu khỏi bộ nhớ đệm, đọc lại đúng dữ liệu đang lưu.
    await prefs.reload();
    throw StateError('Không thể lưu dữ liệu trên thiết bị.');
  }
}
