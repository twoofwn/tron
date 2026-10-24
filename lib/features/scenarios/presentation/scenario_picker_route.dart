import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scenario_lookup.dart';
import '../models/scenario.dart';
import '../providers/scenario_provider.dart';
import 'scenario_library_screen.dart';
import 'scenario_palette.dart';

/// Mở kho kịch bản từ form combo và trả về ID kịch bản đã xác nhận.
/// Quay lại mà không xác nhận thì trả về `null`, combo giữ nguyên.
class ScenarioPickerRoute extends ConsumerStatefulWidget {
  const ScenarioPickerRoute({super.key, this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<ScenarioPickerRoute> createState() =>
      _ScenarioPickerRouteState();
}

class _ScenarioPickerRouteState extends ConsumerState<ScenarioPickerRoute> {
  String? _confirmedId;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(scenarioLibraryProvider);
    return ScenarioTheme(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_confirmedId);
        },
        child: library.when(
          data: (repository) => ScenarioLibraryScreen(
            repository: repository,
            initialSelection: ScenarioSelection(
              scenarioId: ScenarioLookup.canonicalId(
                widget.selectedId ?? ScenarioLookup.bundledIds.first,
              ),
              backgroundId: null,
            ),
            onSelectionChanged: (selection) =>
                _confirmedId = selection.scenarioId,
          ),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không tải được kho kịch bản.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(scenarioLibraryProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
