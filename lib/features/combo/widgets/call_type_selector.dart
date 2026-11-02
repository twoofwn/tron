import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/enums/call_interface.dart';

/// Chọn loại cuộc gọi: gọi thoại (giọng) hoặc gọi video (video tự quay).
class CallTypeSelector extends StatelessWidget {
  const CallTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final CallType selected;
  final ValueChanged<CallType> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final type in CallType.values) ...[
        if (type != CallType.values.first) const SizedBox(width: 9),
        Expanded(
          child: OptionTile(
            icon: type == CallType.video
                ? Icons.videocam_rounded
                : Icons.call_rounded,
            label: type.label,
            isSelected: type == selected,
            onTap: () => onChanged(type),
          ),
        ),
      ],
    ],
  );
}

/// Ô lựa chọn một trong nhiều (biểu tượng + nhãn) dùng chung cho form combo.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isSelected ? AppColors.accent : scheme.onSurface;
    return Semantics(
      selected: isSelected,
      button: true,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.1)
            : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.accent : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
