import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/services/storage_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/providers/combo_provider.dart';
import 'package:tron/features/combo/repositories/combo_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Seeds once, persists edits and preserves an empty collection',
    () async {
      final repository = ComboRepository(StorageService());
      final seeded = await repository.load();
      expect(seeded.length, 3);
      await repository.save([seeded.first.copyWith(name: 'Tên đã sửa')]);
      expect(
        (await ComboRepository(StorageService()).load()).single.name,
        'Tên đã sửa',
      );
      await repository.save([]);
      expect(await repository.load(), isEmpty);
    },
  );
  test(
    'Create, duplicate, import duplicate policy and delete persist',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(comboListProvider.future);
      final notifier = container.read(comboListProvider.notifier);
      final combo = ComboModel(
        id: 'test-combo',
        name: 'Cuộc gọi thử',
        scenarioId: 'boss',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
      );
      await notifier.saveCombo(combo);
      expect(container.read(selectedComboIdProvider), combo.id);
      await notifier.duplicateCombo(combo);
      expect((await container.read(comboListProvider.future)).length, 5);
      expect(await notifier.importCombos([combo], copyDuplicates: false), 0);
      expect(await notifier.importCombos([combo], copyDuplicates: true), 1);
      final combos = await container.read(comboListProvider.future);
      expect(combos.map((combo) => combo.id).toSet().length, combos.length);
      container.read(selectedComboIdProvider.notifier).selectCombo(combo.id);
      await notifier.deleteCombo(combo.id);
      expect(container.read(selectedComboIdProvider), isNull);
      expect((await ComboRepository(StorageService()).load()).length, 5);
    },
  );
}
