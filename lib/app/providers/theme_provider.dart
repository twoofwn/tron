import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/storage_service.dart';

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async =>
      await ref.watch(storageServiceProvider).read('tron.theme') == 'light'
      ? ThemeMode.light
      : ThemeMode.dark;
  Future<void> toggle() async {
    final next = state.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await ref.read(storageServiceProvider).write('tron.theme', next.name);
    state = AsyncData(next);
  }
}
