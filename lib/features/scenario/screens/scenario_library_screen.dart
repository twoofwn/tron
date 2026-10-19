import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../repositories/scenario_repository.dart';

class ScenarioLibraryScreen extends ConsumerWidget {
  const ScenarioLibraryScreen({super.key, this.selectedId});
  final String? selectedId;
  Future<void> _preview(
    BuildContext context,
    WidgetRef ref,
    String dialogue,
  ) async {
    try {
      await ref.read(scenarioPlaybackProvider.notifier).play(dialogue);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Thiết bị chưa phát được giọng đọc tiếng Việt.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    onPopInvokedWithResult: (_, _) =>
        ref.read(scenarioPlaybackProvider.notifier).stop(),
    child: ScreenShell(
      title: 'Thư viện kịch bản',
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Mỗi tình huống, một câu chuyện',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          for (final scenario in ScenarioRepository.scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GlassCard(
                isSelected: selectedId == scenario.id,
                onTap: () => Navigator.pop(context, scenario.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scenario.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          scenario.durationLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scenario.dialogue,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _preview(context, ref, scenario.dialogue),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Nghe thử'),
                        ),
                        if (ref.watch(scenarioPlaybackProvider))
                          IconButton(
                            tooltip: 'Dừng nghe thử',
                            onPressed: () => ref
                                .read(scenarioPlaybackProvider.notifier)
                                .stop(),
                            icon: const Icon(Icons.stop_rounded),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context, scenario.id),
                          child: const Text('Sử dụng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
