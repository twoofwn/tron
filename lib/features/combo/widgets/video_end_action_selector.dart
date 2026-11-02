import 'package:flutter/material.dart';

import '../../../shared/enums/call_interface.dart';
import 'call_type_selector.dart';

/// Chọn việc xảy ra khi video người gọi phát hết: tắt máy hoặc lặp lại.
class VideoEndActionSelector extends StatelessWidget {
  const VideoEndActionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final VideoEndAction selected;
  final ValueChanged<VideoEndAction> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final action in VideoEndAction.values) ...[
        if (action != VideoEndAction.values.first) const SizedBox(width: 9),
        Expanded(
          child: OptionTile(
            icon: action == VideoEndAction.loop
                ? Icons.repeat_rounded
                : Icons.call_end_rounded,
            label: action.label,
            isSelected: action == selected,
            onTap: () => onChanged(action),
          ),
        ),
      ],
    ],
  );
}
