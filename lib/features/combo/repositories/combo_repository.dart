import 'dart:convert';

import '../../../core/services/storage_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../models/combo_model.dart';

class ComboRepository {
  ComboRepository(this.storage);
  final StorageService storage;
  static const _key = 'tron.combos.v1';
  Future<List<ComboModel>> load() async {
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
}
