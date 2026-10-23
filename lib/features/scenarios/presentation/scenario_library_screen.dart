import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/scenario_repository.dart';
import '../data/scenario_search.dart';
import '../models/scenario.dart';
import 'scenario_detail_screen.dart';
import 'scenario_editor_sheet.dart';
import 'scenario_palette.dart';
import 'widgets/background_tile.dart';
import 'widgets/scenario_card.dart';

class ScenarioLibraryScreen extends StatefulWidget {
  const ScenarioLibraryScreen({
    super.key,
    required this.repository,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  final ScenarioRepository repository;
  final ScenarioSelection initialSelection;
  final ValueChanged<ScenarioSelection> onSelectionChanged;

  @override
  State<ScenarioLibraryScreen> createState() => _ScenarioLibraryScreenState();
}

class _ScenarioLibraryScreenState extends State<ScenarioLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  ScenarioFilter _filter = ScenarioFilter.all;
  late ScenarioSelection _selection = widget.initialSelection;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _setSelection(ScenarioSelection selection) {
    setState(() => _selection = selection);
    widget.onSelectionChanged(selection);
  }

  Future<void> _openDetail(Scenario scenario) async {
    final result = await Navigator.of(context).push<ScenarioSelection>(
      MaterialPageRoute(
        builder: (_) => ScenarioDetailScreen(
          repository: widget.repository,
          scenarioId: scenario.id,
          currentSelection: _selection,
        ),
      ),
    );
    if (result != null) _setSelection(result);
  }

  Future<void> _createScenario() async {
    final scenario = await showScenarioEditor(
      context,
      repository: widget.repository,
    );
    if (!mounted || scenario == null) return;
    await _openDetail(scenario);
  }

  Future<void> _addBackground() async {
    try {
      final file = await openFile();
      if (file == null) return;
      final path = await widget.repository.importAudio(
        await file.readAsBytes(),
        file.name,
      );
      final name = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final sound = AmbientSound(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        title: name,
        iconName: 'music',
        audioPath: path,
        isCustom: true,
      );
      await widget.repository.addBackground(sound);
      if (!mounted) return;
      _setSelection(
        _selection.copyWith(backgroundId: sound.id, backgroundOverridden: true),
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đã thêm âm nền “$name”.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thêm được âm nền: $error')));
    }
  }

  Widget _filterChip(ScenarioFilter filter, String label) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = filter),
      showCheckmark: false,
      backgroundColor: ScenarioPalette.card,
      selectedColor: const Color(0xFFF1F2F6),
      labelStyle: TextStyle(
        color: selected ? ScenarioPalette.background : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : ScenarioPalette.outline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = filterScenarios(
      widget.repository.scenarios,
      query: _search.text,
      filter: _filter,
    );
    final backgrounds = widget.repository.backgrounds;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey('scenario-library-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Kho kịch bản',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Thêm kịch bản',
                          style: IconButton.styleFrom(
                            backgroundColor: ScenarioPalette.yellow,
                            foregroundColor: ScenarioPalette.background,
                          ),
                          onPressed: _createScenario,
                          icon: const Icon(Icons.add, size: 29),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Tìm kịch bản...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Xóa tìm kiếm',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: ScenarioPalette.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: ScenarioPalette.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 1,
                      children: [
                        _filterChip(ScenarioFilter.all, 'Tất cả'),
                        _filterChip(ScenarioFilter.family, 'Gia đình'),
                        _filterChip(ScenarioFilter.work, 'Công việc'),
                        _filterChip(ScenarioFilter.custom, 'Tự ghi âm'),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (scenarios.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Không tìm thấy kịch bản phù hợp.',
                      style: TextStyle(color: ScenarioPalette.muted),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    return ScenarioCard(
                      key: ValueKey(scenario.id),
                      scenario: scenario,
                      selected: scenario.id == _selection.scenarioId,
                      onTap: () => _openDetail(scenario),
                    );
                  },
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ÂM THANH NỀN',
                      style: TextStyle(
                        color: ScenarioPalette.muted,
                        fontSize: 13,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 13),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            mainAxisExtent: 90,
                          ),
                      itemCount: backgrounds.length + 2,
                      itemBuilder: (context, index) {
                        if (index == backgrounds.length + 1) {
                          return OutlinedButton.icon(
                            onPressed: _addBackground,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ScenarioPalette.muted,
                              side: const BorderSide(
                                color: ScenarioPalette.outline,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        }
                        final sound = index == backgrounds.length
                            ? null
                            : backgrounds[index];
                        return BackgroundTile(
                          sound: sound,
                          selected: sound?.id == _selection.backgroundId,
                          onTap: () => _setSelection(
                            _selection.copyWith(
                              backgroundId: sound?.id,
                              clearBackground: sound == null,
                              backgroundOverridden: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Âm thanh mẫu được tạo để thử giao diện. Bạn có thể thêm file MP3, M4A hoặc WAV của mình.',
                      style: TextStyle(
                        color: ScenarioPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
