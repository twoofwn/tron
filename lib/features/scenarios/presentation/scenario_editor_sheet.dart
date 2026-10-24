import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/scenario_repository.dart';
import '../models/scenario.dart';
import 'scenario_palette.dart';

Future<Scenario?> showScenarioEditor(
  BuildContext context, {
  required ScenarioRepository repository,
  Scenario? original,
}) => showModalBottomSheet<Scenario>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: ScenarioPalette.of(context).background,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.94,
    child: ScenarioEditorSheet(repository: repository, original: original),
  ),
);

class _EditableLine {
  _EditableLine({required String text, this.audioPath})
    : controller = TextEditingController(text: text),
      originalText = text,
      originalAudioPath = audioPath;

  final TextEditingController controller;
  final String originalText;
  final String? originalAudioPath;
  String? audioPath;

  void dispose() => controller.dispose();
}

class ScenarioEditorSheet extends StatefulWidget {
  const ScenarioEditorSheet({
    super.key,
    required this.repository,
    this.original,
  });

  final ScenarioRepository repository;
  final Scenario? original;

  @override
  State<ScenarioEditorSheet> createState() => _ScenarioEditorSheetState();
}

class _ScenarioEditorSheetState extends State<ScenarioEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.original?.title ?? '',
  );
  late final TextEditingController _caller = TextEditingController(
    text: widget.original?.callerName ?? '',
  );
  late ScenarioCategory _category =
      widget.original?.category ?? ScenarioCategory.personal;
  late final List<_EditableLine> _lines = widget.original == null
      ? [_EditableLine(text: '')]
      : widget.original!.steps
            .where((step) => step.type == DialogueStepType.speech)
            .map(
              (step) =>
                  _EditableLine(text: step.text, audioPath: step.audioPath),
            )
            .toList();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _caller.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseAudio(_EditableLine line) async {
    try {
      final file = await openFile();
      if (file == null) return;
      final path = await widget.repository.importAudio(
        await file.readAsBytes(),
        file.name,
      );
      if (mounted) setState(() => line.audioPath = path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không nhập được audio: $error')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thêm ít nhất một câu thoại.')),
      );
      return;
    }
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      if (line.audioPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Câu ${index + 1} cần file audio.')),
        );
        return;
      }
      if (line.controller.text.trim() != line.originalText.trim() &&
          line.audioPath == line.originalAudioPath) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Câu ${index + 1} đã đổi nội dung. Chọn audio mới cho câu này.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final id = widget.original?.source == ScenarioSource.user
          ? widget.original!.id
          : 'user-${DateTime.now().microsecondsSinceEpoch}';
      final title = _title.text.trim();
      final callerName = _caller.text.trim();
      final steps = <DialogueStep>[];
      for (var index = 0; index < _lines.length; index++) {
        final line = _lines[index];
        steps.add(
          DialogueStep(
            id: '$id-speech-${index + 1}',
            type: DialogueStepType.speech,
            text: line.controller.text.trim(),
            audioPath: line.audioPath,
            seconds: 3,
          ),
        );
        if (index < _lines.length - 1) {
          steps.add(
            DialogueStep(
              id: '$id-wait-${index + 1}',
              type: DialogueStepType.wait,
              text: 'Bạn trả lời · chạm để tiếp tục',
            ),
          );
        }
      }
      final scenario = Scenario(
        id: id,
        title: title,
        category: _category,
        source: ScenarioSource.user,
        callerName: callerName,
        initial: callerName.characters.first.toUpperCase(),
        defaultBackgroundId: widget.original?.defaultBackgroundId,
        steps: steps,
      );
      await widget.repository.saveUserScenario(scenario);
      if (mounted) Navigator.of(context).pop(scenario);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được kịch bản: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCopy = widget.original != null && !widget.original!.isEditable;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isCopy
                        ? 'Sao chép kịch bản'
                        : widget.original == null
                        ? 'Tạo kịch bản'
                        : 'Sửa kịch bản',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                children: [
                  Text(
                    'Mỗi câu thoại cần một file MP3, M4A hoặc WAV. Nếu sửa chữ, hãy chọn file mới khớp nội dung.',
                    style: TextStyle(
                      color: ScenarioPalette.of(context).muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Tên kịch bản',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập tên kịch bản'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _caller,
                    decoration: const InputDecoration(
                      labelText: 'Tên người gọi hiển thị',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập tên người gọi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ScenarioCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Chủ đề'),
                    items: const [
                      DropdownMenuItem(
                        value: ScenarioCategory.family,
                        child: Text('Gia đình'),
                      ),
                      DropdownMenuItem(
                        value: ScenarioCategory.work,
                        child: Text('Công việc'),
                      ),
                      DropdownMenuItem(
                        value: ScenarioCategory.personal,
                        child: Text('Cá nhân'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Câu thoại',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  for (var index = 0; index < _lines.length; index++)
                    _lineEditor(index, _lines[index]),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _lines.add(_EditableLine(text: ''))),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm câu thoại'),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Đang lưu...' : 'Lưu kịch bản'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineEditor(int index, _EditableLine line) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(13),
    decoration: ScenarioPalette.of(context).cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Câu ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Xóa câu ${index + 1}',
              onPressed: _lines.length == 1
                  ? null
                  : () {
                      setState(() => _lines.removeAt(index));
                      line.dispose();
                    },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextFormField(
          controller: line.controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Nội dung câu thoại'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Nhập nội dung câu thoại'
              : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _chooseAudio(line),
          icon: const Icon(Icons.audio_file_outlined),
          label: Text(
            line.audioPath == null
                ? 'Chọn file audio'
                : 'Audio: ${line.audioPath!.split('/').last}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
