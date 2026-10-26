import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/activation/providers/activation_provider.dart';
import '../features/activation/services/call_alarm_service.dart';
import '../features/activation/services/permission_service.dart';
import '../features/combo/providers/combo_provider.dart';
import '../features/fake_call/providers/call_provider.dart';
import '../features/fake_call/screens/fake_call_screen.dart';
import '../shared/enums/call_interface.dart';
import 'providers/app_foreground_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import '../features/scenarios/providers/scenario_provider.dart';
import 'router/route_names.dart';
import 'theme/app_theme.dart';

class TronApp extends ConsumerStatefulWidget {
  const TronApp({super.key});
  @override
  ConsumerState<TronApp> createState() => _TronAppState();
}

class _TronAppState extends ConsumerState<TronApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _alarmTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAlarms());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmTaps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(appForegroundProvider.notifier)
        .setForeground(state == AppLifecycleState.resumed);
    // Người dùng có thể vừa đổi quyền trong cài đặt hệ thống.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionSnapshotProvider);
    }
  }

  Future<void> _startAlarms() async {
    final alarm = ref.read(callAlarmServiceProvider);
    try {
      _alarmTaps = alarm.taps.listen(_ringFromAlarm);
      await alarm.init();
      final comboId = await alarm.launchComboId();
      if (comboId != null) {
        await _ringFromAlarm(comboId);
      }
    } catch (_) {
      // Báo thức là phần bổ sung: lỗi ở đây không được làm app dừng.
    }
  }

  Future<void> _ringFromAlarm(String comboId) async {
    final combos = await ref.read(comboListProvider.future);
    if (!mounted) {
      return;
    }
    final combo = combos.where((item) => item.id == comboId).firstOrNull;
    if (combo != null) {
      ref.read(callProvider.notifier).ringNow(combo);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tải kho kịch bản ngay khi mở app để combo và cuộc gọi dùng được ngay.
    ref.listen(scenarioLibraryProvider, (previous, next) {});
    // Giữ cảm biến cử chỉ theo cài đặt; provider này phải luôn được watch ở gốc app.
    ref.watch(motionActivationProvider);
    ref.watch(backgroundArmingProvider);
    ref.watch(triggerLinkProvider);
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
