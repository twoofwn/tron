import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/combo_model.dart';
import '../repositories/combo_repository.dart';

final comboRepositoryProvider = Provider(
  (ref) => ComboRepository(
    ref.watch(storageServiceProvider),
    api: ref.watch(apiClientProvider),
  ),
);
final comboListProvider =
    AsyncNotifierProvider<ComboListNotifier, List<ComboModel>>(
      ComboListNotifier.new,
    );
final selectedComboIdProvider =
    NotifierProvider<SelectedComboNotifier, String?>(SelectedComboNotifier.new);

class SelectedComboNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void selectCombo(String? comboId) => state = comboId;
}

class ComboListNotifier extends AsyncNotifier<List<ComboModel>> {
  String _copyName(String name) {
    var result = '';
    for (final rune in name.runes) {
      final character = String.fromCharCode(rune);
      if (result.length + character.length > 69) {
        break;
      }
      result += character;
    }
    return '$result (bản sao)';
  }

  @override
  Future<List<ComboModel>> build() => ref.watch(comboRepositoryProvider).load();
  Future<void> _commit(List<ComboModel> combos) async {
    await ref.read(comboRepositoryProvider).save(combos);
    state = AsyncData(List.unmodifiable(combos));
  }

  Future<void> saveCombo(ComboModel combo) async {
    final combos = [...await future];
    final index = combos.indexWhere((item) => item.id == combo.id);
    if (index < 0) {
      combos.add(combo);
    } else {
      combos[index] = combo;
    }
    await _commit(combos);
    ref.read(selectedComboIdProvider.notifier).selectCombo(combo.id);
    try {
      await ref.read(comboRepositoryProvider).upsertRemote(combo);
    } catch (_) {
      // Keep local change even if offline
    }
  }

  Future<void> deleteCombo(String id) async {
    await _commit((await future).where((combo) => combo.id != id).toList());
    if (ref.read(selectedComboIdProvider) == id) {
      ref.read(selectedComboIdProvider.notifier).selectCombo(null);
    }
    try {
      await ref.read(comboRepositoryProvider).deleteRemote(id);
    } catch (_) {
      // Keep local change even if offline
    }
  }

  Future<void> duplicateCombo(ComboModel combo) => saveCombo(
    combo.copyWith(id: const Uuid().v4(), name: _copyName(combo.name)),
  );
  Future<int> importCombos(
    List<ComboModel> incoming, {
    required bool copyDuplicates,
  }) async {
    final combos = [...await future];
    final addedList = <ComboModel>[];
    for (final combo in incoming) {
      final exists = combos.any((item) => item.id == combo.id);
      if (exists && !copyDuplicates) {
        continue;
      }
      final toAdd = exists
          ? combo.copyWith(id: const Uuid().v4(), name: _copyName(combo.name))
          : combo;
      combos.add(toAdd);
      addedList.add(toAdd);
    }
    await _commit(combos);
    for (final item in addedList) {
      try {
        await ref.read(comboRepositoryProvider).upsertRemote(item);
      } catch (_) {}
    }
    return addedList.length;
  }
}
