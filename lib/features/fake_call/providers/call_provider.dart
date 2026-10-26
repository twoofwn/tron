import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/enums/call_interface.dart';
import '../../combo/models/combo_model.dart';
import '../../settings/providers/settings_provider.dart';

class CallState {
  const CallState({
    this.status = CallStatus.idle,
    this.combo,
    this.remaining = Duration.zero,
    this.scheduledAt,
  });
  final CallStatus status;
  final ComboModel? combo;
  final Duration remaining;
  final DateTime? scheduledAt;
}

final callDelayProvider = NotifierProvider<CallDelayNotifier, Duration>(
  CallDelayNotifier.new,
);

class CallDelayNotifier extends Notifier<Duration> {
  @override
  Duration build() =>
      ref.watch(settingsProvider).value?.lastDelay ??
      AppConstants.defaultCallDelay;

  Future<void> select(Duration duration) async {
    state = duration;
    await ref
        .read(settingsProvider.notifier)
        .modify((current) => current.copyWith(lastDelay: duration));
  }
}

final callProvider = NotifierProvider<CallNotifier, CallState>(
  CallNotifier.new,
);

class CallNotifier extends Notifier<CallState> {
  Timer? _timer;
  @override
  CallState build() {
    ref.onDispose(() => _timer?.cancel());
    return const CallState();
  }

  void schedule(ComboModel combo, Duration delay) {
    _timer?.cancel();
    final deadline = DateTime.now().add(delay);
    state = CallState(
      status: CallStatus.scheduled,
      combo: combo,
      remaining: delay,
      scheduledAt: deadline,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _timer?.cancel();
        state = CallState(status: CallStatus.ringing, combo: combo);
      } else {
        state = CallState(
          status: CallStatus.scheduled,
          combo: combo,
          remaining: remaining,
          scheduledAt: deadline,
        );
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    state = const CallState();
  }

  void answer() {
    state = CallState(status: CallStatus.inProgress, combo: state.combo);
  }
}
