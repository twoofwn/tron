import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scenario_repository.dart';

final scenarioRepositoryProvider = Provider<ScenarioRepository>((ref) {
  final repository = ScenarioRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Tải kho kịch bản một lần; các màn khác đọc kết quả qua `.value`.
final scenarioLibraryProvider = FutureProvider<ScenarioRepository>((ref) async {
  final repository = ref.watch(scenarioRepositoryProvider);
  await repository.load();
  return repository;
});
