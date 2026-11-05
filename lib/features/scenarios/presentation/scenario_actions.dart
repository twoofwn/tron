import 'package:flutter/material.dart';

import '../data/scenario_repository.dart';
import '../models/scenario.dart';
import 'scenario_editor_sheet.dart';
import 'scenario_palette.dart';

enum ScenarioAction { edit, copy, restore, delete }

/// Các việc làm được với một kịch bản trong kho: sửa, tạo bản sao (kịch bản
/// mẫu), khôi phục bản gốc (kịch bản mẫu đã sửa) và xoá.
List<ScenarioAction> scenarioActionsFor(
  ScenarioRepository repository,
  Scenario scenario,
) => [
  ScenarioAction.edit,
  if (scenario.source != ScenarioSource.user) ScenarioAction.copy,
  if (repository.isEditedBuiltIn(scenario)) ScenarioAction.restore,
  ScenarioAction.delete,
];

/// Chạy [action]. Trả về kịch bản sau khi sửa/sao chép, `null` nếu huỷ hoặc
/// sau khi xoá/khôi phục.
Future<Scenario?> runScenarioAction(
  BuildContext context, {
  required ScenarioRepository repository,
  required Scenario scenario,
  required ScenarioAction action,
}) async {
  switch (action) {
    case ScenarioAction.edit || ScenarioAction.copy:
      return showScenarioEditor(
        context,
        repository: repository,
        original: scenario,
        asCopy: action == ScenarioAction.copy,
      );
    case ScenarioAction.restore:
      final confirmed = await _confirm(
        context,
        title: 'Khôi phục bản gốc?',
        message:
            'Bản sửa của “${scenario.title}” và giọng đã thu cho nó sẽ bị xoá. '
            'Combo đang dùng kịch bản này sẽ dùng lại bản mẫu của app.',
        action: 'Khôi phục',
      );
      if (confirmed) await repository.restoreBuiltIn(scenario);
      return null;
    case ScenarioAction.delete:
      final isPersonal =
          scenario.source == ScenarioSource.user &&
          !repository.isEditedBuiltIn(scenario);
      final confirmed = await _confirm(
        context,
        title: 'Xoá kịch bản?',
        message: isPersonal
            ? '“${scenario.title}” và giọng đã thu sẽ bị xoá khỏi máy. Combo '
                  'đang dùng kịch bản này sẽ chuyển sang kịch bản mặc định.'
            : '“${scenario.title}” sẽ không còn hiện trong kho. Combo đang '
                  'dùng vẫn gọi được. Bạn có thể hiện lại ở cuối Kho kịch bản.',
        action: 'Xoá',
      );
      if (confirmed) await repository.deleteScenario(scenario);
      return null;
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ==
    true;

/// Nút ⋮ mở danh sách việc làm được với kịch bản.
class ScenarioMenuButton extends StatelessWidget {
  const ScenarioMenuButton({
    super.key,
    required this.repository,
    required this.scenario,
    required this.onSelected,
  });

  final ScenarioRepository repository;
  final Scenario scenario;
  final ValueChanged<ScenarioAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = ScenarioPalette.of(context);
    final danger = Theme.of(context).colorScheme.error;
    return PopupMenuButton<ScenarioAction>(
      tooltip: 'Tuỳ chọn ${scenario.title}',
      icon: Icon(Icons.more_vert, color: palette.muted),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final action in scenarioActionsFor(repository, scenario))
          PopupMenuItem(
            value: action,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (action) {
                ScenarioAction.edit => Icons.edit_outlined,
                ScenarioAction.copy => Icons.copy_outlined,
                ScenarioAction.restore => Icons.restore,
                ScenarioAction.delete => Icons.delete_outline,
              }, color: action == ScenarioAction.delete ? danger : null),
              title: Text(
                switch (action) {
                  ScenarioAction.edit => 'Sửa',
                  ScenarioAction.copy => 'Tạo bản sao',
                  ScenarioAction.restore => 'Khôi phục bản gốc',
                  ScenarioAction.delete => 'Xoá',
                },
                style: action == ScenarioAction.delete
                    ? TextStyle(color: danger)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
