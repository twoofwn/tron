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
          child: _CallTypeOption(
            type: type,
            isSelected: type == selected,
            onTap: () => onChanged(type),
          ),
        ),
      ],
    ],
  );
}

class _CallTypeOption extends StatelessWidget {
  const _CallTypeOption({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });
  final CallType type;
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
      label: type.label,
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
                Icon(
                  type == CallType.video
                      ? Icons.videocam_rounded
                      : Icons.call_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type.label,
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
