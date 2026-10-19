import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/fake_call/providers/call_provider.dart';
import 'package:tron/shared/enums/call_interface.dart';

void main() {
  final combo = ComboModel(
    id: 'test',
    name: 'Test',
    scenarioId: 'boss',
    callInterface: CallInterface.phone,
    createdAt: DateTime(2026),
  );
  test('Scheduling rings once and can be answered and cancelled', () async {
    final container = ProviderContainer();
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
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(callProvider.notifier);
    notifier.schedule(combo, const Duration(milliseconds: 10));
    notifier.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(container.read(callProvider).status, CallStatus.idle);
  });
}
