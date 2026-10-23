import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../models/combo_package.dart';
import 'combo_checklist.dart';

class ImportPreview extends StatelessWidget {
  const ImportPreview({
    super.key,
    required this.package,
    required this.selectedIds,
    required this.existingIds,
    required this.copyDuplicates,
    required this.isBusy,
    required this.onSelectionChanged,
    required this.onCopyDuplicatesChanged,
    required this.onConfirm,
  });
  final ComboPackage package;
  final Set<String> selectedIds;
  final Set<String> existingIds;
  final bool copyDuplicates;
  final bool isBusy;
  final void Function(String, bool) onSelectionChanged;
  final ValueChanged<bool> onCopyDuplicatesChanged;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 26),
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
      if (package.combos.any((combo) => existingIds.contains(combo.id))) ...[
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
      const SizedBox(height: 20),
      AppButton(
        label: 'Xác nhận nhập · ${selectedIds.length} combo',
        icon: Icons.download_done_rounded,
        isLoading: isBusy,
        onPressed: selectedIds.isEmpty ? null : onConfirm,
      ),
    ],
  );
}
