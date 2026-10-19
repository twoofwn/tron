import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../combo/models/combo_model.dart';

class ComboChecklist extends StatelessWidget {
  const ComboChecklist({
    super.key,
    required this.combos,
    required this.selectedIds,
    required this.onChanged,
    this.isEnabled = true,
    this.existingIds = const {},
  });
  final List<ComboModel> combos;
  final Set<String> selectedIds;
  final void Function(String id, bool isSelected) onChanged;
  final bool isEnabled;
  final Set<String> existingIds;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        if (combos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Bạn chưa có combo nào để chia sẻ.'),
          ),
        for (var index = 0; index < combos.length; index++) ...[
          if (index > 0) const Divider(),
          CheckboxListTile(
            value: selectedIds.contains(combos[index].id),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: isEnabled
                ? (value) => onChanged(combos[index].id, value ?? false)
                : null,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              combos[index].name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: existingIds.contains(combos[index].id)
                ? const Text(
                    'Đã có trên thiết bị',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  )
                : null,
            secondary: Text(
              combos[index].callInterface.label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ],
    ),
  );
}
