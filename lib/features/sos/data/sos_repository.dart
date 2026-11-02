import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../../../core/services/storage_service.dart';
import '../models/sos_settings.dart';

/// Lưu cài đặt SOS trên máy (không đồng bộ lên server).
class SosRepository {
  SosRepository(this._storage);

  final StorageService _storage;

  Future<SosSettings> load() async {
    final raw = await _storage.read(AppConfig.sosKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return SosSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        // Dữ liệu hỏng: dùng mặc định thay vì làm hỏng màn hình.
      }
    }
    // Bản cũ chỉ lưu một số "người bạn tin cậy": chuyển sang danh sách mới.
    final legacy = SosContact.normalizePhone(
      await _storage.read(AppConfig.emergencyKey) ?? '',
    );
    if (legacy == null) {
      return const SosSettings();
    }
    return SosSettings(
      contacts: [SosContact(id: 'legacy', name: '', phone: legacy)],
    );
  }

  Future<void> save(SosSettings settings) =>
      _storage.write(AppConfig.sosKey, jsonEncode(settings.toJson()));
}
