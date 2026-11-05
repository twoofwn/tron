import 'dart:typed_data';

import '../../combo/models/combo_model.dart';
import '../../scenarios/models/scenario.dart';

class ComboPackage {
  const ComboPackage({
    required this.id,
    required this.combos,
    this.scenarios = const [],
    this.audio = const {},
  });
  final String id;
  final List<ComboModel> combos;
  final List<Scenario> scenarios;
  final Map<String, Uint8List> audio;
}
