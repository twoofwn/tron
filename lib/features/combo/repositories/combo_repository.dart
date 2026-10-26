import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../models/combo_model.dart';

class ComboRepository {
  ComboRepository(this.storage, {this.api});
  final StorageService storage;
  final ApiClient? api;
  static const _key = AppConfig.combosKey;

  Future<List<ComboModel>> load() async {
    if (api != null && await api!.hasToken()) {
      try {
        final remoteList = await api!.getList('/combos');
        final combos = remoteList.map(fromServerMap).toList();
        await save(combos);
        return combos;
      } catch (_) {
        // Fallback to local cache if server is temporarily unreachable
      }
    }

    final value = await storage.read(_key);
    if (value != null) {
      return (jsonDecode(value) as List)
          .map(
            (item) =>
                ComboModel.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
    }
    final initial = [
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-111111111111',
        name: 'Sếp gọi gấp',
        scenarioId: 'boss',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
        backgroundSoundPaths: const ['office'],
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-222222222222',
        name: 'Mẹ gọi về nhà',
        scenarioId: 'mother',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
        ringtoneType: RingtoneType.classic,
        backgroundSoundPaths: const ['television'],
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-333333333333',
        name: 'Lan rủ đi gấp',
        scenarioId: 'friend',
        callInterface: CallInterface.messenger,
        createdAt: DateTime(2026),
        backgroundSoundPaths: const ['traffic', 'cafe'],
      ),
    ];
    await save(initial);
    return initial;
  }

  Future<void> save(List<ComboModel> combos) => storage.write(
    _key,
    jsonEncode(combos.map((combo) => combo.toJson()).toList()),
  );

  Future<void> upsertRemote(ComboModel combo) async {
    if (api == null || !await api!.hasToken()) return;
    await api!.postJson('/combos', toServerMap(combo));
  }

  Future<void> deleteRemote(String id) async {
    if (api == null || !await api!.hasToken()) return;
    await api!.delete('/combos/$id');
  }

  static String ensureGuid(String rawId) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRegex.hasMatch(rawId)) {
      return rawId.toLowerCase();
    }
    final bytes = md5.convert(utf8.encode('tron-combo:$rawId')).bytes;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Map<String, dynamic> toServerMap(ComboModel combo) => {
    'id': ensureGuid(combo.id),
    'name': combo.name,
    'scenarioId': combo.scenarioId,
    'callInterface': combo.callInterface.name,
    'ringtoneType': combo.ringtoneType == RingtoneType.custom
        ? RingtoneType.interfaceDefault.name
        : combo.ringtoneType.name,
    'ringtoneMediaId': null,
    'backgroundSoundIds': combo.backgroundSoundPaths,
    'customBackgroundMediaId': null,
    'backgroundVolume': 0.3,
    'backgroundOverridden': false,
    'createdAt': combo.createdAt.toUtc().toIso8601String(),
  };

  static ComboModel fromServerMap(Map<String, dynamic> map) {
    final bgList = ((map['backgroundSoundIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .where(
          (key) => BackgroundSound.values.any(
            (sound) => sound.name.toLowerCase() == key.toLowerCase(),
          ),
        )
        .toList();
    final callInterfaceStr = (map['callInterface'] as String? ?? 'phone')
        .toLowerCase();
    final callInterface = CallInterface.values.firstWhere(
      (e) => e.name.toLowerCase() == callInterfaceStr,
      orElse: () => CallInterface.phone,
    );
    final ringtoneTypeStr =
        (map['ringtoneType'] as String? ?? 'interfaceDefault').toLowerCase();
    final ringtoneType = RingtoneType.values.firstWhere(
      (e) => e.name.toLowerCase() == ringtoneTypeStr,
      orElse: () => RingtoneType.interfaceDefault,
    );
    return ComboModel(
      id:
          (map['id'] as String?) ??
          'combo-${DateTime.now().microsecondsSinceEpoch}',
      name: (map['name'] as String?) ?? 'Combo',
      scenarioId: (map['scenarioId'] as String?) ?? 'mother',
      callInterface: callInterface,
      ringtoneType: ringtoneType,
      backgroundSoundPaths: bgList,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
