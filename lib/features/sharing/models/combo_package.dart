import 'dart:typed_data';

import '../../combo/models/combo_model.dart';

class ComboPackage {
  const ComboPackage({
    required this.id,
    required this.combos,
    this.audio = const {},
  });
  final String id;
  final List<ComboModel> combos;
  final Map<String, Uint8List> audio;
}
