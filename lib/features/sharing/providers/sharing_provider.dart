import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combo/providers/combo_provider.dart';
import '../../scenarios/models/scenario.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../models/combo_package.dart';
import '../repositories/sharing_repository.dart';

final sharingActionsProvider = Provider((ref) => SharingActions(ref));

class SharingActions {
  SharingActions(this.ref);
  final Ref ref;

  Future<int> importPackage(
    ComboPackage package,
    Set<String> selectedIds, {
    Set<String>? selectedScenarioIds,
    required bool copyDuplicates,
  }) async {
    final repository = ref.read(sharingRepositoryProvider);
    final scenarioRepo = await ref.read(scenarioLibraryProvider.future);

    final scenarioIdsToSave = <String>{
      ...(selectedScenarioIds ?? package.scenarios.map((s) => s.id)),
    };
    for (final combo in package.combos) {
      if (selectedIds.contains(combo.id)) {
        scenarioIdsToSave.add(combo.scenarioId);
      }
    }

    var importedScenariosCount = 0;
    for (final sc in package.scenarios) {
      if (scenarioIdsToSave.contains(sc.id)) {
        await scenarioRepo.saveUserScenario(
          sc.copyWith(source: ScenarioSource.user),
        );
        importedScenariosCount++;
      }
    }
    if (importedScenariosCount > 0) {
      ref.invalidate(scenarioLibraryProvider);
    }

    if (selectedIds.isEmpty) {
      return importedScenariosCount;
    }

    final notifier = ref.read(comboListProvider.notifier);
    final existing = await ref.read(comboListProvider.future);
    final existingIds = existing.map((combo) => combo.id).toSet();
    final selected = copyDuplicates
        ? {...selectedIds}
        : selectedIds.difference(existingIds);
    final combos = await repository.materialize(package, selected);
    final importedCombosCount = await notifier.importCombos(
      combos,
      copyDuplicates: copyDuplicates,
    );
    return importedCombosCount + importedScenariosCount;
  }
}
