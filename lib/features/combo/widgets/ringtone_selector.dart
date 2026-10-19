import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/enums/call_interface.dart';

class RingtoneSelector extends StatelessWidget {
  const RingtoneSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onPickFile,
    this.hasCustomFile = false,
  });
  final RingtoneType selected;
  final ValueChanged<RingtoneType> onChanged;
  final VoidCallback onPickFile;
  final bool hasCustomFile;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _option(
          context,
          RingtoneType.interfaceDefault,
          'Theo giao diện đã chọn',
          Icons.chevron_right_rounded,
        ),
        const Divider(),
        _option(
          context,
          RingtoneType.classic,
          'Chuông cổ điển',
          Icons.chevron_right_rounded,
        ),
        const Divider(),
        _option(
          context,
          RingtoneType.custom,
          hasCustomFile ? 'Đã chọn âm thanh cá nhân' : 'Chọn từ máy (.mp3)',
          Icons.music_note_outlined,
        ),
      ],
    ),
  );
  Widget _option(
    BuildContext context,
    RingtoneType type,
    String label,
    IconData icon,
  ) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: Icon(
      selected == type
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_off_rounded,
      size: 21,
      color: selected == type ? AppColors.accent : AppColors.muted,
    ),
    title: Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    trailing: Icon(icon, size: 18, color: AppColors.muted),
    onTap: () => type == RingtoneType.custom ? onPickFile() : onChanged(type),
  );
}
