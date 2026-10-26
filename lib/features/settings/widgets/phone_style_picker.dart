import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/app_settings.dart';

class PhoneStylePicker extends StatelessWidget {
  const PhoneStylePicker({
    super.key,
    required this.selected,
    required this.detected,
    required this.onSelected,
  });

  final PhoneStyle selected;
  final PhoneStyle? detected;
  final ValueChanged<PhoneStyle> onSelected;

  static const _styles = [
    PhoneStyle.iphone,
    PhoneStyle.samsung,
    PhoneStyle.xiaomi,
    PhoneStyle.huawei,
  ];

  @override
  Widget build(BuildContext context) {
    final auto = selected == PhoneStyle.auto;
    final shown = auto ? detected : selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 168,
          children: [
            for (final style in _styles)
              _StyleTile(
                style: style,
                selected: shown == style,
                onTap: () => onSelected(style),
              ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: auto,
          title: const Text('Tự nhận diện theo máy đang dùng'),
          subtitle: auto && detected != null
              ? Text('Đang dùng: ${detected!.label}')
              : null,
          onChanged: (value) => onSelected(
            value == true ? PhoneStyle.auto : (detected ?? PhoneStyle.iphone),
          ),
        ),
      ],
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final PhoneStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.accent : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _PhonePreview(style: style)),
                const SizedBox(height: 10),
                Text(
                  style.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.accent : null,
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

/// Minh họa nút nghe và từ chối, theo bố cục màn gọi của từng hãng.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.style});

  final PhoneStyle style;

  @override
  Widget build(BuildContext context) {
    final isIphone = style == PhoneStyle.iphone;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: isIphone ? 44 : 30,
            height: isIphone ? 6 : 30,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(isIphone ? 3 : 15),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Dot(color: isIphone ? AppColors.red : AppColors.green),
              _Dot(color: isIphone ? AppColors.green : AppColors.red),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
