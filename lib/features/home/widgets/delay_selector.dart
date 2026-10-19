import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../fake_call/providers/call_provider.dart';

class DelaySelector extends ConsumerWidget {
  const DelaySelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(callDelayProvider);
    return Row(
      children: [
        for (
          var index = 0;
          index < AppConstants.callDelays.length;
          index++
        ) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: ChoiceChip(
              showCheckmark: false,
              label: Center(
                child: Text(
                  delayLabel(AppConstants.callDelays[index]),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              labelPadding: EdgeInsets.zero,
              selected: selected == AppConstants.callDelays[index],
              onSelected: (_) => ref
                  .read(callDelayProvider.notifier)
                  .select(AppConstants.callDelays[index]),
            ),
          ),
        ],
      ],
    );
  }
}
