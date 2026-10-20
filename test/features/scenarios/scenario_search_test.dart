import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/scenarios/data/scenario_search.dart';
import 'package:tron/features/scenarios/models/scenario.dart';

void main() {
  const scenarios = [
    Scenario(
      id: 'mother',
      title: 'Mẹ gọi về gấp',
      category: ScenarioCategory.family,
      source: ScenarioSource.builtIn,
      callerName: 'Mẹ',
      initial: 'M',
      defaultBackgroundId: null,
      steps: [],
    ),
    Scenario(
      id: 'boss',
      title: 'Sếp báo server sập',
      category: ScenarioCategory.work,
      source: ScenarioSource.builtIn,
      callerName: 'Sếp Hùng',
      initial: 'S',
      defaultBackgroundId: null,
      steps: [],
    ),
    Scenario(
      id: 'personal',
      title: 'Lan rủ đi gấp',
      category: ScenarioCategory.family,
      source: ScenarioSource.user,
      callerName: 'Lan',
      initial: 'L',
      defaultBackgroundId: null,
      steps: [],
    ),
  ];

  test('Vietnamese search combines with category filter', () {
    final result = filterScenarios(
      scenarios,
      query: 'ME Goi',
      filter: ScenarioFilter.family,
    );
    expect(result.map((item) => item.id), ['mother']);
    expect(
      filterScenarios(
        scenarios,
        query: 'server',
        filter: ScenarioFilter.family,
      ),
      isEmpty,
    );
  });

  test('custom filter uses source independently of category', () {
    final result = filterScenarios(
      scenarios,
      query: 'lan',
      filter: ScenarioFilter.custom,
    );
    expect(result.single.category, ScenarioCategory.family);
  });
}
