import 'dart:async';

import 'package:flutter/material.dart';

import '../data/scenario_repository.dart';
import '../models/scenario.dart';
import '../services/scenario_preview_player.dart';
import 'scenario_editor_sheet.dart';
import 'scenario_palette.dart';

class ScenarioDetailScreen extends StatefulWidget {
  const ScenarioDetailScreen({
    super.key,
    required this.repository,
    required this.scenarioId,
    required this.currentSelection,
    this.previewPlayer,
  });

  final ScenarioRepository repository;
  final String scenarioId;
  final ScenarioSelection currentSelection;
  final ScenarioPreviewPlayer? previewPlayer;

  @override
  State<ScenarioDetailScreen> createState() => _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends State<ScenarioDetailScreen>
    with WidgetsBindingObserver {
  late String _scenarioId = widget.scenarioId;
  late final ScenarioPreviewPlayer _preview =
      widget.previewPlayer ?? ScenarioPreviewPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preview.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_preview.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preview.removeListener(_refresh);
    if (widget.previewPlayer == null) unawaited(_preview.close());
    super.dispose();
  }

  String? _effectiveBackgroundId(Scenario scenario) =>
      widget.currentSelection.backgroundOverridden
      ? widget.currentSelection.backgroundId
      : scenario.defaultBackgroundId;

  Future<void> _edit(Scenario scenario) async {
    await _preview.stop();
    if (!mounted) return;
    final updated = await showScenarioEditor(
      context,
      repository: widget.repository,
      original: scenario,
    );
    if (mounted && updated != null) setState(() => _scenarioId = updated.id);
  }

  Future<void> _delete(Scenario scenario) async {
    await _preview.stop();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa kịch bản cá nhân?'),
        content: Text('“${scenario.title}” sẽ bị xóa khỏi bộ nhớ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.deleteUserScenario(scenario.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _confirm(Scenario scenario) {
    unawaited(_preview.stop());
    Navigator.of(context).pop(
      ScenarioSelection(
        scenarioId: scenario.id,
        backgroundId: _effectiveBackgroundId(scenario),
        backgroundVolume: widget.currentSelection.backgroundVolume,
        backgroundOverridden: widget.currentSelection.backgroundOverridden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenario = widget.repository.findScenario(_scenarioId);
    if (scenario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kịch bản')),
        body: const Center(child: Text('Không tìm thấy kịch bản.')),
      );
    }
    final sound = widget.repository.findBackground(
      _effectiveBackgroundId(scenario),
    );
    final palette = ScenarioPalette.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 19, 20, 14),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            scenario.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _edit(scenario),
                          child: Text(scenario.isEditable ? 'Sửa' : 'Sao chép'),
                        ),
                        if (scenario.isEditable)
                          IconButton(
                            tooltip: 'Xóa kịch bản',
                            onPressed: () => _delete(scenario),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCell(
                            'Tên hiển thị',
                            scenario.callerName,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _summaryCell(
                            'Âm nền',
                            sound == null
                                ? 'Không có'
                                : '${sound.title} · ${(widget.currentSelection.backgroundVolume * 100).round()}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: palette.cardDecoration(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.graphic_eq, color: palette.yellowText),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Bản nghe thử: sau câu chờ, hãy chạm “Tiếp tục” khi bạn đã trả lời.',
                              style: TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 23),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: scenario.steps.length,
                itemBuilder: (context, index) {
                  final step = scenario.steps[index];
                  final isSpeech = step.type == DialogueStepType.speech;
                  final number = scenario.steps
                      .take(index + 1)
                      .where((item) => item.type == DialogueStepType.speech)
                      .length;
                  final active = _preview.activeStepId == step.id;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: isSpeech ? 15 : 13,
                                backgroundColor: active
                                    ? palette.yellow
                                    : isSpeech
                                    ? palette.stepBadge
                                    : palette.card,
                                child: isSpeech
                                    ? Text(
                                        '$number',
                                        style: TextStyle(
                                          color: active
                                              ? palette.onYellow
                                              : palette.yellowText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : Icon(
                                        Icons.mic_none,
                                        size: 16,
                                        color: palette.muted,
                                      ),
                              ),
                              if (index < scenario.steps.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 1.5,
                                    color: palette.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 22),
                            child: isSpeech
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${scenario.callerName} · 0:${step.seconds.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: palette.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '“${step.text}”',
                                        style: TextStyle(
                                          fontSize: 17,
                                          height: 1.35,
                                          fontWeight: active
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: active
                                              ? palette.yellowText
                                              : palette.text,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    step.text,
                                    style: TextStyle(
                                      color: active
                                          ? palette.yellowText
                                          : palette.muted,
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 9, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_preview.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _preview.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_preview.waitingForReply)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _preview.continueAfterReply,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Tiếp tục câu thoại'),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_preview.isPlaying) {
                          unawaited(_preview.stop());
                        } else {
                          unawaited(
                            _preview.start(
                              scenario,
                              background: sound,
                              volume: widget.currentSelection.backgroundVolume,
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        _preview.isPlaying ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(_preview.isPlaying ? 'Dừng' : 'Nghe thử'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        foregroundColor: palette.text,
                        side: BorderSide(color: palette.outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => _confirm(scenario),
                      child: const Text(
                        'Dùng kịch bản này',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCell(String label, String value) {
    final palette = ScenarioPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 65),
      padding: const EdgeInsets.all(13),
      decoration: palette.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
