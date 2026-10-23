import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/scenarios/data/scenario_lookup.dart';

void main() {
  test('bundledIds matches assets/scenarios/scenarios.json', () {
    final entries = jsonDecode(
      File('assets/scenarios/scenarios.json').readAsStringSync(),
    ) as List<dynamic>;
    final ids = entries.map((e) => (e as Map)['id'] as String).toSet();
    expect(ScenarioLookup.bundledIds, ids);
  });

  test('legacy combo IDs map to bundled scenarios', () {
    for (final entry in ScenarioLookup.legacyIds.entries) {
      expect(ScenarioLookup.canonicalId(entry.key), entry.value);
      expect(ScenarioLookup.bundledIds, contains(entry.value));
    }
    expect(ScenarioLookup.canonicalId('landlord-rent'), 'landlord-rent');
  });

  test('without a loaded library, legacy scenarios still resolve', () {
    final info = ScenarioLookup.resolve('boss', null);
    expect(info.title, isNotEmpty);
    expect(info.dialogue, isNotEmpty);
  });

  test('shareable IDs cover legacy and bundled, reject unknown', () {
    expect(ScenarioLookup.isShareableId('boss'), isTrue);
    expect(ScenarioLookup.isShareableId('delivery'), isTrue);
    expect(ScenarioLookup.isShareableId('boss-server'), isTrue);
    expect(ScenarioLookup.isShareableId('unknown'), isFalse);
  });
}
