import 'dart:convert';

import '../../../core/services/storage_service.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  const SettingsRepository(this._storage);

  static const _key = 'tron.settings';

  final StorageService _storage;

  /// Dữ liệu hỏng hoặc không đọc được thì dùng mặc định, không làm app dừng.
  Future<AppSettings> load() async {
    final raw = await _storage.read(_key);
    if (raw == null) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const AppSettings();
    } on TypeError {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) =>
      _storage.write(_key, jsonEncode(settings.toJson()));
}
