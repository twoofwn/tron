import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combo/providers/combo_provider.dart';
import '../models/combo_package.dart';
import '../repositories/sharing_repository.dart';

final sharingActionsProvider = Provider((ref) => SharingActions(ref));

class SharingActions {
  SharingActions(this.ref);
  final Ref ref;

  Future<int> importPackage(
    ComboPackage package,
    Set<String> selectedIds, {
    required bool copyDuplicates,
  }) async {
    final repository = ref.read(sharingRepositoryProvider);
    final notifier = ref.read(comboListProvider.notifier);
    final existing = await ref.read(comboListProvider.future);
    final existingIds = existing.map((combo) => combo.id).toSet();
    final selected = copyDuplicates
        ? {...selectedIds}
        : selectedIds.difference(existingIds);
    final combos = await repository.materialize(package, selected);
    return notifier.importCombos(combos, copyDuplicates: copyDuplicates);
  }
}
