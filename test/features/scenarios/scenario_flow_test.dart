import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/scenarios/presentation/scenario_library_screen.dart';
import 'package:tron/features/scenarios/presentation/scenario_palette.dart';

class _FakeRepository extends ScenarioRepository {
  static const _mother = Scenario(
    id: 'mother',
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
        audioPath: 'audio/voice/mother_1.wav',
        seconds: 2,
      ),
    ],
  );
  static const _boss = Scenario(
    id: 'boss',
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
        audioPath: 'audio/voice/boss_1.wav',
        seconds: 2,
      ),
    ],
  );

  @override
  List<Scenario> get scenarios => const [_mother, _boss];

  @override
  Scenario? findScenario(String id) =>
      scenarios.where((item) => item.id == id).firstOrNull;
}

void main() {
  testWidgets('detail back cancels; confirm selects the scenario', (
    tester,
  ) async {
    final repository = _FakeRepository();
    ScenarioSelection? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ScenarioPalette.theme,
        home: ScenarioLibraryScreen(
          repository: repository,
          initialSelection: const ScenarioSelection(
            scenarioId: 'mother',
            backgroundId: 'television',
          ),
          onSelectionChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Sếp báo server sập'));
    await tester.pumpAndSettle();
    expect(find.text('Dùng kịch bản này'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại').last);
    await tester.pumpAndSettle();
    expect(selected, isNull);

    await tester.tap(find.text('Sếp báo server sập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dùng kịch bản này'));
    await tester.pumpAndSettle();
    expect(selected?.scenarioId, 'boss');
    expect(selected?.backgroundId, 'office');
    expect(find.text('Đang chọn'), findsOneWidget);
    repository.dispose();
  });

  testWidgets('library and detail fit a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ScenarioPalette.theme,
        home: ScenarioLibraryScreen(
          repository: repository,
          initialSelection: const ScenarioSelection(
            scenarioId: 'mother',
            backgroundId: 'television',
          ),
          onSelectionChanged: (_) {},
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mẹ gọi về gấp'));
    await tester.pumpAndSettle();
    expect(find.text('Dùng kịch bản này'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.dispose();
  });
}
