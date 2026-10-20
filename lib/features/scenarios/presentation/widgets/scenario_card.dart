import 'package:flutter/material.dart';

import '../../models/scenario.dart';
import '../scenario_palette.dart';

class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.selected,
    required this.onTap,
  });

  final Scenario scenario;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarColor = switch (scenario.category) {
      ScenarioCategory.family => const Color(0xFF362B18),
      ScenarioCategory.work => const Color(0xFF1C283D),
      ScenarioCategory.personal => const Color(0xFF32213B),
    };
    final letterColor = switch (scenario.category) {
      ScenarioCategory.family => ScenarioPalette.yellow,
      ScenarioCategory.work => const Color(0xFF8EB6F8),
      ScenarioCategory.personal => const Color(0xFFD6A4E7),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Ink(
            decoration: ScenarioPalette.cardDecoration(selected: selected),
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    scenario.initial,
                    style: TextStyle(
                      color: letterColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${scenario.categoryLabel} · ${scenario.speechCount} câu · ~${scenario.estimatedCallSeconds} giây',
                        style: const TextStyle(
                          color: ScenarioPalette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ScenarioPalette.yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Đang chọn',
                      style: TextStyle(
                        color: ScenarioPalette.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: ScenarioPalette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
