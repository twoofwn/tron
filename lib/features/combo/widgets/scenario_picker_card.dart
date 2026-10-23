import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../scenarios/data/scenario_lookup.dart';

class ScenarioPickerCard extends StatelessWidget {
  const ScenarioPickerCard({
    super.key,
    required this.scenario,
    required this.isPlaying,
    required this.onChoose,
    required this.onPreview,
  });
  final ScenarioInfo scenario;
  final bool isPlaying;
  final VoidCallback onChoose;
  final VoidCallback onPreview;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
    onTap: onChoose,
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFF202C42),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: AppColors.blue,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kịch bản',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                scenario.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isPlaying ? 'Dừng nghe thử' : 'Nghe thử kịch bản',
          onPressed: onPreview,
          icon: Icon(
            isPlaying
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline_rounded,
            color: AppColors.accent,
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.muted,
        ),
      ],
    ),
  );
}
