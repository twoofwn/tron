import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../fake_call/providers/call_provider.dart';

class DelaySelector extends ConsumerWidget {
  const DelaySelector({super.key});

  static const _columns = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(callDelayProvider);
    final delays = AppConstants.callDelays;
    // 7 mức không vừa một hàng: chia hàng 4 nút để nhãn "30 phút" vẫn đọc rõ.
    // Dùng Row/Column thay cho GridView vì trang chủ bọc trong IntrinsicHeight.
    return Column(
      children: [
        for (var start = 0; start < delays.length; start += _columns) ...[
          if (start > 0) const SizedBox(height: 7),
          Row(
            children: [
              for (var column = 0; column < _columns; column++) ...[
                if (column > 0) const SizedBox(width: 7),
                Expanded(
                  child: start + column < delays.length
                      ? _DelayChip(
                          delay: delays[start + column],
                          selected: selected == delays[start + column],
                          onSelected: () =>
                              _select(context, ref, delays[start + column]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    Duration delay,
  ) async {
    try {
      await ref.read(callDelayProvider.notifier).select(delay);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Chưa thể lưu mức gọi sau.');
      }
    }
  }
}

class _DelayChip extends StatelessWidget {
  const _DelayChip({
    required this.delay,
    required this.selected,
    required this.onSelected,
  });

  final Duration delay;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    showCheckmark: false,
    label: Center(
      child: Text(
        delayLabel(delay),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    padding: const EdgeInsets.symmetric(vertical: 6),
    labelPadding: EdgeInsets.zero,
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}
