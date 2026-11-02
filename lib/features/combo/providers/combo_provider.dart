import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/combo_model.dart';
import '../repositories/combo_repository.dart';

final comboRepositoryProvider = Provider(
  (ref) => ComboRepository(
    ref.watch(storageServiceProvider),
    api: ref.watch(apiClientProvider),
    files: ref.watch(fileServiceProvider),
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

  Future<void> saveCombo(ComboModel edited) async {
    // Đánh dấu chờ gửi; bỏ dấu khi server đã nhận (xem _applySync).
    final combo = edited.copyWith(syncPending: true);
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
      await _applySync(
        await ref.read(comboRepositoryProvider).upsertRemote(combo),
      );
    } catch (_) {
      // Keep local change even if offline; syncPending makes load() retry.
    }
  }

  /// Ghi kết quả đồng bộ vào combo hiện có trong danh sách (theo id), chỉ khi
  /// nội dung combo chưa đổi kể từ lúc gửi, để không đè một thay đổi mới hơn.
  Future<void> _applySync(ComboModel? synced) async {
    if (synced == null) {
      return;
    }
    final combos = [...await future];
    final index = combos.indexWhere((item) => item.id == synced.id);
    if (index < 0 || !combos[index].sameContentAs(synced)) {
      return;
    }
    combos[index] = combos[index].copyWith(
      voiceMediaId: synced.voiceMediaId,
      clearVoiceMediaId: synced.voiceMediaId == null,
      videoMediaId: synced.videoMediaId,
      clearVideoMediaId: synced.videoMediaId == null,
      syncPending: false,
    );
    await _commit(combos);
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
      // Thông tin đồng bộ thuộc tài khoản khác: bỏ đi, giọng/video sẽ được tải lên lại.
      final toAdd =
          (exists
                  ? combo.copyWith(
                      id: const Uuid().v4(),
                      name: _copyName(combo.name),
                    )
                  : combo)
              .withoutSync();
      combos.add(toAdd);
      addedList.add(toAdd);
    }
    await _commit(combos);
    for (final item in addedList) {
      try {
        await _applySync(
          await ref.read(comboRepositoryProvider).upsertRemote(item),
        );
      } catch (_) {}
    }
    return addedList.length;
  }
}
