import 'package:flutter/material.dart';

import '../../../shared/enums/call_interface.dart';

class BackgroundSoundSelector extends StatelessWidget {
  const BackgroundSoundSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onPickFile,
    this.hasCustomFile = false,
    this.onRemoveCustom,
  });
  final Set<String> selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickFile;
  final VoidCallback? onRemoveCustom;
  final bool hasCustomFile;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 7,
    children: [
      for (final sound in BackgroundSound.values)
        FilterChip(
          label: Text(sound.label, style: const TextStyle(fontSize: 12)),
          selected: selected.contains(sound.name),
          showCheckmark: false,
          onSelected: (_) => onChanged(sound.name),
        ),
      if (hasCustomFile)
        InputChip(
          label: const Text('Âm thanh của bạn', style: TextStyle(fontSize: 12)),
          onDeleted: onRemoveCustom,
          onPressed: onPickFile,
        )
      else
        ActionChip(
          label: const Text('+ Nhạc của bạn', style: TextStyle(fontSize: 12)),
          onPressed: onPickFile,
        ),
    ],
  );
}
