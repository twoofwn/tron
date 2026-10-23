import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_loading.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../combo/providers/combo_provider.dart';
import '../widgets/export_panel.dart';
import '../widgets/import_panel.dart';

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});
  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  bool _isExport = true;
  @override
  Widget build(BuildContext context) => ScreenShell(
    title: 'Chia sẻ combo',
    child: ref
        .watch(comboListProvider)
        .when(
          loading: () => const AppLoading(),
          error: (_, _) => const Center(
            child: Text('Không thể tải combo. Vui lòng quay lại và thử lại.'),
          ),
          data: (combos) => ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    for (final isExport in [true, false])
                      Expanded(
                        child: Semantics(
                          selected: _isExport == isExport,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _isExport = isExport),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                    alpha: _isExport == isExport ? 1 : 0.5,
                                  ),
                              backgroundColor: _isExport == isExport
                                  ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.09)
                                  : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isExport ? 'Xuất' : 'Nhập',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_isExport)
                ExportPanel(
                  combos: combos,
                  onImport: () => setState(() => _isExport = false),
                )
              else
                ImportPanel(existingCombos: combos),
            ],
          ),
        ),
  );
}
