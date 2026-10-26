import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/account_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/combo/models/combo_model.dart';
import '../../features/combo/screens/combo_form_screen.dart';
import '../../features/fake_call/screens/fake_call_screen.dart';
import '../../features/home/screens/camouflage_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/scenarios/presentation/scenario_picker_route.dart';
import '../../features/sharing/screens/sharing_screen.dart';
import '../app.dart';
import 'route_names.dart';

class _HomeOrAuthGate extends ConsumerWidget {
  const _HomeOrAuthGate();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requireGate = ref.watch(requireAuthGateProvider);
    final authUser = ref.watch(authStateProvider).value;
    if (requireGate && authUser == null) {
      return const AuthScreen();
    }
    return const HomeScreen();
  }
}

abstract final class AppRouter {
  static Route<Object?> generate(RouteSettings settings) => MaterialPageRoute(
    settings: settings,
    builder: (_) => switch (settings.name) {
      RouteNames.home => const _HomeOrAuthGate(),
      RouteNames.comboForm => ComboFormScreen(
        combo: settings.arguments as ComboModel?,
      ),
      RouteNames.sharing => const SharingScreen(),
      RouteNames.scenarios => ScenarioPickerRoute(
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
      RouteNames.auth => const AuthScreen(),
      RouteNames.account => const AccountScreen(),
      _ => const _HomeOrAuthGate(),
    },
  );
}
