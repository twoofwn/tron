import '../models/scenario.dart';

enum ScenarioFilter { all, family, work, custom }

String normalizeVietnamese(String input) {
  const source = [
    'àáạảãâầấậẩẫăằắặẳẵ',
    'èéẹẻẽêềếệểễ',
    'ìíịỉĩ',
    'òóọỏõôồốộổỗơờớợởỡ',
    'ùúụủũưừứựửữ',
    'ỳýỵỷỹ',
    'đ',
  ];
  const target = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
  var result = input.toLowerCase();
  for (var group = 0; group < source.length; group++) {
    for (final character in source[group].split('')) {
      result = result.replaceAll(character, target[group]);
    }
  }
  return result.trim();
}

List<Scenario> filterScenarios(
  Iterable<Scenario> scenarios, {
  required String query,
  required ScenarioFilter filter,
}) {
  final normalizedQuery = normalizeVietnamese(query);
  return scenarios
      .where((scenario) {
        final matchesFilter = switch (filter) {
          ScenarioFilter.all => true,
          ScenarioFilter.family => scenario.category == ScenarioCategory.family,
          ScenarioFilter.work => scenario.category == ScenarioCategory.work,
          ScenarioFilter.custom => scenario.source != ScenarioSource.builtIn,
        };
        final matchesQuery =
            normalizedQuery.isEmpty ||
            normalizeVietnamese('${scenario.title} ${scenario.callerName}')
                .contains(normalizedQuery);
        return matchesFilter && matchesQuery;
      })
      .toList(growable: false);
}
