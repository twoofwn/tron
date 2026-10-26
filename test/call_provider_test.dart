import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/features/activation/services/call_alarm_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/shared/enums/call_interface.dart';

class FakeAlarm extends CallAlarmService {
  final scheduled = <(String, DateTime)>[];
  int cancelled = 0;

  @override
  Future<bool> scheduleCall({
    required String comboId,
    required DateTime fireAt,
  }) async {
    scheduled.add((comboId, fireAt));
    return true;
  }

  @override
  Future<void> cancel() async {
    cancelled++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final combo = ComboModel(
    id: 'test',
    name: 'Test',
    scenarioId: 'boss',
    callInterface: CallInterface.phone,
    createdAt: DateTime(2026),
  );

  test('Scheduling rings once and can be answered and cancelled', () async {
    final container = ProviderContainer(
      overrides: [callAlarmServiceProvider.overrideWithValue(FakeAlarm())],
    );
    addTearDown(container.dispose);
    final events = <CallStatus>[];
    container.listen(callProvider, (_, next) => events.add(next.status));
    final notifier = container.read(callProvider.notifier);
    notifier.schedule(combo, const Duration(milliseconds: 10));
    expect(container.read(callProvider).status, CallStatus.scheduled);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(container.read(callProvider).status, CallStatus.ringing);
    expect(events.where((event) => event == CallStatus.ringing).length, 1);
    notifier.answer();
    expect(container.read(callProvider).status, CallStatus.inProgress);
    notifier.cancel();
    expect(container.read(callProvider).combo, isNull);
  });

  test('Cancelling prevents a pending timer from ringing', () async {
    final container = ProviderContainer(
      overrides: [callAlarmServiceProvider.overrideWithValue(FakeAlarm())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(callProvider.notifier);
    notifier.schedule(combo, const Duration(milliseconds: 10));
    notifier.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(container.read(callProvider).status, CallStatus.idle);
  });

  test('Schedule arms a system alarm at the chosen time', () async {
    final alarm = FakeAlarm();
    final container = ProviderContainer(
      overrides: [callAlarmServiceProvider.overrideWithValue(alarm)],
    );
    addTearDown(container.dispose);
    final armed = await container
        .read(callProvider.notifier)
        .schedule(combo, const Duration(seconds: 30));
    expect(armed, isTrue);
    expect(alarm.scheduled.single.$1, 'test');
  });

  test('Ringing from the timer cancels the system alarm', () async {
    final alarm = FakeAlarm();
    final container = ProviderContainer(
      overrides: [callAlarmServiceProvider.overrideWithValue(alarm)],
    );
    addTearDown(container.dispose);
    container
        .read(callProvider.notifier)
        .schedule(combo, const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(container.read(callProvider).status, CallStatus.ringing);
    expect(alarm.cancelled, greaterThanOrEqualTo(1));
  });

  test('Opening from an alarm rings immediately, only once', () async {
    final container = ProviderContainer(
      overrides: [callAlarmServiceProvider.overrideWithValue(FakeAlarm())],
    );
    addTearDown(container.dispose);
    final events = <CallStatus>[];
    container.listen(callProvider, (_, next) => events.add(next.status));
    final notifier = container.read(callProvider.notifier);
    notifier.ringNow(combo);
    notifier.ringNow(combo);
    expect(container.read(callProvider).status, CallStatus.ringing);
    expect(events.where((event) => event == CallStatus.ringing).length, 1);
  });
}
