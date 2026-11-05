import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/combo_package.dart';
import 'combo_checklist.dart';

class ImportPreview extends StatelessWidget {
  const ImportPreview({
    super.key,
    required this.package,
    required this.selectedIds,
    this.selectedScenarioIds = const {},
    required this.existingIds,
    required this.copyDuplicates,
    required this.isBusy,
    required this.onSelectionChanged,
    this.onScenarioSelectionChanged,
    required this.onCopyDuplicatesChanged,
    required this.onConfirm,
  });
  final ComboPackage package;
  final Set<String> selectedIds;
  final Set<String> selectedScenarioIds;
  final Set<String> existingIds;
  final bool copyDuplicates;
  final bool isBusy;
  final void Function(String, bool) onSelectionChanged;
  final void Function(String, bool)? onScenarioSelectionChanged;
  final ValueChanged<bool> onCopyDuplicatesChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final totalSelected = selectedIds.length + selectedScenarioIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        if (package.scenarios.isNotEmpty) ...[
          Text(
            '${package.scenarios.length} kịch bản trong gói',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final sc in package.scenarios) ...[
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: CheckboxListTile(
                value: selectedScenarioIds.contains(sc.id),
                onChanged: isBusy || onScenarioSelectionChanged == null
                    ? null
                    : (val) => onScenarioSelectionChanged!(sc.id, val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  sc.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'Người gọi: ${sc.callerName} · ${sc.speechCount} câu thoại',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (package.combos.isNotEmpty) const SizedBox(height: 12),
        ],
        if (package.combos.isNotEmpty) ...[
          Text(
            '${package.combos.length} combo trong gói',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ComboChecklist(
            combos: package.combos,
            selectedIds: selectedIds,
            onChanged: onSelectionChanged,
            isEnabled: !isBusy,
            existingIds: existingIds,
          ),
          if (package.combos.any(
            (combo) => existingIds.contains(combo.id),
          )) ...[
            const SizedBox(height: 16),
            const Text(
              'Khi combo đã tồn tại',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Bỏ qua')),
                ButtonSegment(value: true, label: Text('Tạo bản sao')),
              ],
              selected: {copyDuplicates},
              onSelectionChanged: isBusy
                  ? null
                  : (value) => onCopyDuplicatesChanged(value.first),
            ),
          ],
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Xác nhận nhập · $totalSelected mục',
          icon: Icons.download_done_rounded,
          isLoading: isBusy,
          onPressed: totalSelected == 0 ? null : onConfirm,
        ),
      ],
    );
  }
}
