import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/enums/call_interface.dart';

class CallInterfaceSelector extends StatelessWidget {
  const CallInterfaceSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final CallInterface selected;
  final ValueChanged<CallInterface> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final interface in CallInterface.values) ...[
        if (interface != CallInterface.phone) const SizedBox(width: 9),
        Expanded(
          child: _InterfaceOption(
            interface: interface,
            isSelected: interface == selected,
            onTap: () => onChanged(interface),
          ),
        ),
      ],
    ],
  );
}

class _InterfaceOption extends StatelessWidget {
  const _InterfaceOption({
    required this.interface,
    required this.isSelected,
    required this.onTap,
  });
  final CallInterface interface;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewColor = switch (interface) {
      CallInterface.phone => const Color(0xFF303640),
      CallInterface.zalo => const Color(0xFF1264D9),
      CallInterface.messenger => const Color(0xFF211832),
    };
    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Giao diện ${interface.label}',
      child: Material(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.1)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.accent : scheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 102,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: interface == CallInterface.messenger
                            ? const Color(0xFF8563F1)
                            : Colors.white.withValues(
                                alpha: interface == CallInterface.zalo
                                    ? 1
                                    : 0.25,
                              ),
                        child: Icon(
                          Icons.person_rounded,
                          color: previewColor,
                          size: 15,
                        ),
                      ),
                      const Spacer(),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(Icons.circle, color: AppColors.red, size: 14),
                          Icon(Icons.circle, color: AppColors.green, size: 14),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(
                      interface == CallInterface.phone
                          ? interface.label
                          : 'Kiểu ${interface.label}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? AppColors.accent : scheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
