import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/scenarios/presentation/scenario_picker_route.dart';
import 'package:tron/features/scenarios/providers/scenario_provider.dart';

class _FakeRepository extends ScenarioRepository {
  static const _scenarios = [
    Scenario(
      id: 'mother-urgent',
      title: 'Mẹ gọi về gấp',
      category: ScenarioCategory.family,
      source: ScenarioSource.builtIn,
      callerName: 'Mẹ',
      initial: 'M',
      defaultBackgroundId: 'television',
      steps: [
        DialogueStep(
          id: 'm1',
          type: DialogueStepType.speech,
          text: 'Alo, con à?',
          seconds: 2,
        ),
      ],
    ),
    Scenario(
      id: 'boss-server',
      title: 'Sếp báo server sập',
      category: ScenarioCategory.work,
      source: ScenarioSource.builtIn,
      callerName: 'Sếp',
      initial: 'S',
      defaultBackgroundId: 'office',
      steps: [
        DialogueStep(
          id: 'b1',
          type: DialogueStepType.speech,
          text: 'Server sập.',
          seconds: 2,
        ),
      ],
    ),
  ];

  @override
  List<Scenario> get scenarios => _scenarios;

  @override
  Scenario? findScenario(String id) =>
      _scenarios.where((item) => item.id == id).firstOrNull;
}

Future<Object?> _open(WidgetTester tester, Future<void> Function() act) async {
  final repository = _FakeRepository();
  addTearDown(repository.dispose);
  Object? result = 'pending';
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scenarioLibraryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(
                  builder: (_) => const ScenarioPickerRoute(selectedId: 'boss'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  return result;
}

void main() {
  testWidgets('confirming a scenario returns its ID', (tester) async {
    final result = await _open(tester, () async {
      await tester.tap(find.text('Mẹ gọi về gấp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dùng kịch bản này'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quay lại').last);
      await tester.pumpAndSettle();
    });
    expect(result, 'mother-urgent');
  });

  testWidgets('leaving without confirming returns null', (tester) async {
    final result = await _open(tester, () async {
      await tester.tap(find.byTooltip('Quay lại').last);
      await tester.pumpAndSettle();
    });
    expect(result, isNull);
  });
}
