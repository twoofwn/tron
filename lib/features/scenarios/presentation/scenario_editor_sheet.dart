import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/services/file_service.dart';
import '../../../core/services/voice_recorder.dart';
import '../data/scenario_repository.dart';
import '../models/scenario.dart';
import '../services/scenario_preview_player.dart';
import 'scenario_palette.dart';

Future<Scenario?> showScenarioEditor(
  BuildContext context, {
  required ScenarioRepository repository,
  Scenario? original,
  VoiceRecorder? recorder,
  PreviewAudioBackend? player,
}) => showModalBottomSheet<Scenario>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: ScenarioPalette.of(context).background,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.94,
    child: ScenarioEditorSheet(
      repository: repository,
      original: original,
      recorder: recorder,
      player: player,
    ),
  ),
);

class _EditableLine {
  _EditableLine({required String text, this.audioPath, this.waitAfter = true})
    : controller = TextEditingController(text: text),
      originalText = text,
      originalAudioPath = audioPath;

  final TextEditingController controller;
  final String originalText;
  final String? originalAudioPath;
  String? audioPath;

  /// Người gọi chờ người dùng trả lời sau câu này rồi mới nói câu tiếp.
  bool waitAfter;

  /// Câu này đã được thu trong lần sửa này.
  bool recorded = false;

  bool get usesSampleVoice =>
      audioPath != null && ScenarioRepository.isBundledAudio(audioPath!);

  void dispose() => controller.dispose();
}

/// Form tạo / sửa / sao chép kịch bản. Mỗi câu thoại thu giọng trực tiếp
/// hoặc chọn file, nghe lại được, và chọn có chờ người dùng trả lời hay không.
class ScenarioEditorSheet extends StatefulWidget {
  const ScenarioEditorSheet({
    super.key,
    required this.repository,
    this.original,
    this.recorder,
    this.player,
  });

  final ScenarioRepository repository;
  final Scenario? original;

  /// Bộ thu và bộ phát thay thế (dùng trong test).
  final VoiceRecorder? recorder;
  final PreviewAudioBackend? player;

  /// Mỗi câu thu tối đa chừng này: câu thoại cuộc gọi thường chỉ vài giây.
  static const maxLineDuration = Duration(seconds: 30);

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
  late final List<_EditableLine> _lines = _linesFrom(widget.original);
  bool _saving = false;
  bool _saved = false;

  VoiceRecorder? _ownRecorder;
  PreviewAudioBackend? _ownPlayer;
  VoiceRecorder get _recorder =>
      widget.recorder ?? (_ownRecorder ??= VoiceRecorder(FileService()));
  PreviewAudioBackend get _player =>
      widget.player ?? (_ownPlayer ??= DevicePreviewAudioBackend());

  _EditableLine? _recordingLine;
  _EditableLine? _playingLine;
  bool _recorderBusy = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _ticker;

  /// File thu / nhập trong lần sửa này: đóng form không lưu thì xoá hết.
  final _newFiles = <String>{};

  static List<_EditableLine> _linesFrom(Scenario? original) {
    if (original == null) return [_EditableLine(text: '')];
    final lines = <_EditableLine>[];
    for (final step in original.steps) {
      if (step.type == DialogueStepType.speech) {
        lines.add(
          _EditableLine(
            text: step.text,
            audioPath: step.audioPath,
            waitAfter: false,
          ),
        );
      } else if (lines.isNotEmpty) {
        lines.last.waitAfter = true;
      }
    }
    return lines.isEmpty ? [_EditableLine(text: '')] : lines;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recordingLine != null) unawaited(_recorder.cancel());
    if (_playingLine != null) unawaited(_player.stop());
    if (!_saved) {
      for (final path in _newFiles) {
        unawaited(widget.repository.deleteAudio(path));
      }
    }
    _ownRecorder?.dispose();
    unawaited(_ownPlayer?.dispose());
    _title.dispose();
    _caller.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Gắn audio mới cho câu. Audio cũ vừa thu / nhập trong lần sửa này thì
  /// xoá luôn vì không còn dùng.
  void _setAudio(_EditableLine line, String path, {required bool recorded}) {
    final previous = line.audioPath;
    if (previous != null && _newFiles.remove(previous)) {
      unawaited(widget.repository.deleteAudio(previous));
    }
    _newFiles.add(path);
    setState(() {
      line.audioPath = path;
      line.recorded = recorded;
    });
  }

  Future<void> _chooseAudio(_EditableLine line) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: ScenarioRepository.audioTypeGroups,
      );
      if (file == null) return;
      final path = await widget.repository.importAudioFile(file);
      if (!mounted || !_lines.contains(line)) {
        unawaited(widget.repository.deleteAudio(path));
        return;
      }
      _setAudio(line, path, recorded: false);
    } catch (error) {
      _showMessage(ScenarioRepository.importErrorMessage(error));
    }
  }

  Future<void> _stopPlayback() async {
    if (_playingLine == null) return;
    setState(() => _playingLine = null);
    await _player.stop();
  }

  Future<void> _togglePlay(_EditableLine line) async {
    final path = line.audioPath;
    if (path == null || _recordingLine != null) return;
    final wasPlaying = _playingLine == line;
    await _stopPlayback();
    if (wasPlaying || !mounted) return;
    setState(() => _playingLine = line);
    try {
      await _player.playVoice(path);
    } catch (_) {
      _showMessage('Không phát được giọng của câu này.');
    } finally {
      if (mounted && _playingLine == line) {
        setState(() => _playingLine = null);
      }
    }
  }

  Future<void> _startRecording(_EditableLine line) async {
    if (_recorderBusy || _recordingLine != null) return;
    setState(() => _recorderBusy = true);
    try {
      // Tắt giọng đang phát để không lọt vào bản thu.
      await _stopPlayback();
      if (!await _recorder.start()) {
        _showMessage(
          'Cần quyền micro để thu giọng. Bật lại trong Cài đặt của máy.',
        );
        return;
      }
      if (!mounted || !_lines.contains(line)) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _recordingLine = line;
        _recordElapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordElapsed += const Duration(seconds: 1));
        if (_recordElapsed >= ScenarioEditorSheet.maxLineDuration) {
          unawaited(_stopRecording(reachedLimit: true));
        }
      });
    } catch (_) {
      _showMessage('Không bật được micro trên thiết bị này.');
    } finally {
      if (mounted) setState(() => _recorderBusy = false);
    }
  }

  Future<void> _stopRecording({bool reachedLimit = false}) async {
    final line = _recordingLine;
    if (line == null) return;
    _ticker?.cancel();
    setState(() {
      _recordingLine = null;
      _recorderBusy = true;
    });
    try {
      final bytes = await _recorder.stopBytes();
      if (bytes == null) {
        _showMessage(
          'Bản thu quá ngắn hoặc không có tiếng. Hãy nói ít nhất 1 giây.',
        );
        return;
      }
      final path = await widget.repository.importAudio(bytes, 'cau.wav');
      if (!mounted || !_lines.contains(line)) {
        unawaited(widget.repository.deleteAudio(path));
        return;
      }
      _setAudio(line, path, recorded: true);
      if (reachedLimit) {
        _showMessage(
          'Đã đủ ${ScenarioEditorSheet.maxLineDuration.inSeconds} giây nên '
          'bản thu tự dừng và được giữ lại.',
        );
      }
    } catch (_) {
      _showMessage('Không lưu được bản thu. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _recorderBusy = false);
    }
  }

  Future<void> _removeLine(_EditableLine line) async {
    if (_recordingLine == line) {
      _ticker?.cancel();
      setState(() => _recordingLine = null);
      await _recorder.cancel();
    }
    if (_playingLine == line) await _stopPlayback();
    final path = line.audioPath;
    if (path != null && _newFiles.remove(path)) {
      unawaited(widget.repository.deleteAudio(path));
    }
    if (!mounted) return;
    setState(() => _lines.remove(line));
    line.dispose();
  }

  void _addLine() => setState(() {
    // Câu cuối cũ giờ có câu sau: mặc định chờ người dùng trả lời.
    if (_lines.isNotEmpty) _lines.last.waitAfter = true;
    _lines.add(_EditableLine(text: ''));
  });

  Future<void> _save() async {
    if (_recordingLine != null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      _showMessage('Thêm ít nhất một câu thoại.');
      return;
    }
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      if (line.audioPath == null) {
        _showMessage('Câu ${index + 1} chưa có giọng. Bấm Thu hoặc chọn file.');
        return;
      }
      if (line.controller.text.trim() != line.originalText.trim() &&
          line.audioPath == line.originalAudioPath) {
        _showMessage(
          'Câu ${index + 1} đã đổi nội dung. Thu lại hoặc chọn file mới cho '
          'câu này.',
        );
        return;
      }
    }
    await _stopPlayback();
    setState(() => _saving = true);
    try {
      final original = widget.original;
      final editsInPlace = original?.source == ScenarioSource.user;
      final id = editsInPlace
          ? original!.id
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
        if (line.waitAfter && index < _lines.length - 1) {
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
        defaultBackgroundId: original?.defaultBackgroundId,
        steps: steps,
      );
      await widget.repository.saveUserScenario(scenario);
      _saved = true;
      // Dọn audio không còn câu nào dùng: bản thu bị thay trong lần sửa
      // này, và audio cũ của chính kịch bản cá nhân đang sửa. Bản sao của
      // kịch bản mẫu không đụng vào audio gốc.
      final used = {for (final line in _lines) line.audioPath};
      final unused = {
        ..._newFiles,
        if (editsInPlace)
          for (final step in original!.steps)
            if (step.audioPath != null) step.audioPath!,
      }.where((path) => !used.contains(path));
      for (final path in unused) {
        unawaited(widget.repository.deleteAudio(path));
      }
      if (mounted) Navigator.of(context).pop(scenario);
    } catch (error) {
      _showMessage('Không lưu được kịch bản: $error');
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
                    'Mỗi câu cần giọng: bấm Thu để đọc trực tiếp, hoặc chọn '
                    'file MP3, M4A, WAV. Sửa chữ thì thu lại cho khớp.',
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
                    onPressed: _addLine,
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
                  onPressed: _saving || _recordingLine != null ? null : _save,
                  child: Text(
                    _saving
                        ? 'Đang lưu...'
                        : _recordingLine != null
                        ? 'Đang thu giọng...'
                        : 'Lưu kịch bản',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _clock(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:'
      '${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _lineEditor(int index, _EditableLine line) {
    final palette = ScenarioPalette.of(context);
    final isRecording = _recordingLine == line;
    final isPlaying = _playingLine == line;
    final otherRecording = _recordingLine != null && !isRecording;
    final isLast = index == _lines.length - 1;
    final remaining = ScenarioEditorSheet.maxLineDuration - _recordElapsed;
    final (String status, Color statusColor) = isRecording
        ? (
            remaining <= const Duration(seconds: 10)
                ? 'Đang thu ${_clock(_recordElapsed)} · còn '
                      '${remaining.inSeconds} giây, hết giờ tự dừng'
                : 'Đang thu ${_clock(_recordElapsed)} / '
                      '${_clock(ScenarioEditorSheet.maxLineDuration)}',
            Colors.redAccent,
          )
        : line.audioPath == null
        ? ('Chưa có giọng', palette.muted)
        : line.usesSampleVoice
        ? (
            'Giọng mẫu của app · bấm Thu lại để dùng giọng của bạn',
            palette.muted,
          )
        : line.recorded
        ? ('Giọng tự thu', palette.muted)
        : ('File: ${line.audioPath!.split('/').last}', palette.muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: palette.cardDecoration(),
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
                onPressed: _lines.length == 1 ? null : () => _removeLine(line),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            controller: line.controller,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Nội dung câu thoại'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập nội dung câu thoại'
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isRecording
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text('Dừng ${_clock(_recordElapsed)}'),
                      )
                    : OutlinedButton.icon(
                        onPressed: otherRecording || _recorderBusy
                            ? null
                            : () => _startRecording(line),
                        icon: const Icon(Icons.mic_rounded),
                        label: Text(
                          line.audioPath == null ? 'Thu giọng' : 'Thu lại',
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Chọn file cho câu ${index + 1}',
                onPressed: _recordingLine != null
                    ? null
                    : () => _chooseAudio(line),
                icon: const Icon(Icons.audio_file_outlined),
              ),
              IconButton(
                tooltip: isPlaying
                    ? 'Dừng nghe câu ${index + 1}'
                    : 'Nghe câu ${index + 1}',
                onPressed: line.audioPath == null || _recordingLine != null
                    ? null
                    : () => _togglePlay(line),
                icon: Icon(
                  isPlaying ? Icons.stop_circle_outlined : Icons.play_arrow,
                ),
              ),
            ],
          ),
          Text(
            status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: statusColor),
          ),
          if (!isLast)
            // Thẻ có nền riêng: cần lớp Material để hiệu ứng chạm hiện lên.
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Chờ người dùng trả lời sau câu này'),
                value: line.waitAfter,
                onChanged: (value) =>
                    setState(() => line.waitAfter = value ?? true),
              ),
            ),
        ],
      ),
    );
  }
}
