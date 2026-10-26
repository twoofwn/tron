import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/storage_service.dart';

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async =>
      await ref.watch(storageServiceProvider).read(AppConfig.themeKey) ==
          'light'
      ? ThemeMode.light
      : ThemeMode.dark;
  Future<void> toggle() async {
    final next = state.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await ref.read(storageServiceProvider).write(AppConfig.themeKey, next.name);
    state = AsyncData(next);
    final api = ref.read(apiClientProvider);
    if (await api.hasToken()) {
      try {
        await api.putJson('/me/settings', {
          'themeMode': next.name,
          'defaultCallDelaySeconds': 30,
        });
      } catch (_) {}
    }
  }
}
