import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/combo/models/combo_model.dart';
import '../../features/combo/screens/combo_form_screen.dart';
import '../../features/fake_call/screens/fake_call_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/camouflage_screen.dart';
import '../../features/scenario/screens/scenario_library_screen.dart';
import '../../features/sharing/screens/sharing_screen.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static Route<Object?> generate(RouteSettings settings) => MaterialPageRoute(
    settings: settings,
    builder: (_) => switch (settings.name) {
      RouteNames.home => const HomeScreen(),
      RouteNames.comboForm => ComboFormScreen(
        combo: settings.arguments as ComboModel?,
      ),
      RouteNames.sharing => const SharingScreen(),
      RouteNames.scenarios => ScenarioLibraryScreen(
        selectedId: settings.arguments as String?,
      ),
      RouteNames.fakeCall => ProviderScope(
        overrides: [callSessionProvider.overrideWith(CallSessionNotifier.new)],
        child: FakeCallScreen(
          arguments: settings.arguments is ComboModel
              ? FakeCallArguments(settings.arguments as ComboModel)
              : settings.arguments as FakeCallArguments,
        ),
      ),
      RouteNames.camouflage => const CamouflageScreen(),
      _ => const HomeScreen(),
    },
  );
}
