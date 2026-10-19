import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/fake_call/providers/call_provider.dart';
import '../features/fake_call/screens/fake_call_screen.dart';
import '../shared/enums/call_interface.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'router/route_names.dart';
import 'theme/app_theme.dart';

class TronApp extends ConsumerStatefulWidget {
  const TronApp({super.key});
  @override
  ConsumerState<TronApp> createState() => _TronAppState();
}

class _TronAppState extends ConsumerState<TronApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    ref.listen(callProvider, (previous, next) {
      if (previous?.status != CallStatus.ringing &&
          next.status == CallStatus.ringing &&
          next.combo != null) {
        _navigatorKey.currentState?.pushNamed(
          RouteNames.fakeCall,
          arguments: FakeCallArguments(next.combo!, isPreview: false),
        );
      }
    });
    return MaterialApp(
      title: 'TRỐN · Lối thoát của bạn',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      onGenerateRoute: AppRouter.generate,
      theme: AppTheme.create(Brightness.light),
      darkTheme: AppTheme.create(Brightness.dark),
      themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.dark,
    );
  }
}
