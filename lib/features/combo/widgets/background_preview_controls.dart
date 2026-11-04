import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../settings/models/app_settings.dart';

/// Nghe thử các âm nền đang chọn và chỉnh âm lượng nền trong cuộc gọi.
class BackgroundPreviewControls extends StatelessWidget {
  const BackgroundPreviewControls({
    super.key,
    required this.hasSelection,
    required this.isPlaying,
    required this.volume,
    required this.onToggle,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
  });

  final bool hasSelection;
  final bool isPlaying;
  final double volume;
  final VoidCallback onToggle;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;

  @override
  Widget build(BuildContext context) {
    final percent = '${(volume * 100).round()}%';
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: hasSelection || isPlaying ? onToggle : null,
            icon: Icon(
              isPlaying
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline_rounded,
              color: hasSelection || isPlaying
                  ? AppColors.accent
                  : AppColors.muted,
            ),
            label: Text(
              isPlaying ? 'Dừng nghe thử' : 'Nghe thử âm nền',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (!hasSelection && !isPlaying)
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                'Chọn ít nhất một âm nền để nghe thử.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.volume_down_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
              Expanded(
                child: Slider(
                  value: volume,
                  min: AppSettings.minBackgroundVolume,
                  divisions: 9,
                  label: percent,
                  semanticFormatterCallback: (_) => 'Âm lượng âm nền $percent',
                  onChanged: onVolumeChanged,
                  onChangeEnd: onVolumeChangeEnd,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  percent,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Âm lượng nền so với giọng người gọi, dùng cho mọi combo.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
