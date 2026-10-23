import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

class StorageService {
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  Future<void> write(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Không thể lưu dữ liệu trên thiết bị.');
    }
  }
}
