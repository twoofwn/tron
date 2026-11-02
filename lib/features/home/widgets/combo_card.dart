import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/enums/call_interface.dart';
import '../../combo/models/combo_model.dart';

class ComboCard extends StatelessWidget {
  const ComboCard({
    super.key,
    required this.combo,
    required this.isSelected,
    required this.onTap,
    this.onMenu,
  });
  final ComboModel combo;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  @override
  Widget build(BuildContext context) {
    final color = switch (combo.callInterface) {
      CallInterface.zalo => AppColors.blue,
      CallInterface.phone => AppColors.accent,
      CallInterface.messenger => AppColors.purple,
    };
    return GlassCard(
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onMenu,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(
              combo.name.characters.first.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(combo.name, style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    ComboTag(combo.callInterface.label, color: color),
                    // Gọi video không phát âm nền: không hiện nhãn âm nền.
                    if (!combo.isVideoCall) ...[
                      for (final key in combo.backgroundSoundPaths)
                        ComboTag(BackgroundSound.values.byName(key).label),
                      if (combo.customBackgroundPath != null)
                        const ComboTag('Âm thanh riêng'),
                    ],
                    if (combo.isVideoCall) ...[
                      ComboTag(
                        combo.videoPath == null ? 'Gọi video' : 'Video tự quay',
                        color: AppColors.green,
                      ),
                      if (combo.videoEndAction == VideoEndAction.loop)
                        const ComboTag('Lặp video'),
                    ] else if (combo.voicePath != null)
                      const ComboTag('Giọng tự thu'),
                    ComboTag(switch (combo.ringtoneType) {
                      RingtoneType.classic => 'Chuông cổ điển',
                      RingtoneType.custom => 'Chuông cá nhân',
                      RingtoneType.interfaceDefault => 'Chuông theo giao diện',
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            checked: isSelected,
            inMutuallyExclusiveGroup: true,
            label: 'Chọn ${combo.name}',
            button: true,
            child: Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.accent : AppColors.muted,
              size: 22,
            ),
          ),
          if (onMenu != null)
            SizedBox(
              width: 27,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: onMenu,
                tooltip: 'Quản lý ${combo.name}',
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class ComboTag extends StatelessWidget {
  const ComboTag(this.label, {super.key, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: (color ?? AppColors.muted).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
