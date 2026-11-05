import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/storage_service.dart';
import '../../backup/services/backup_service.dart';
import '../../sharing/models/combo_package.dart';
import '../../sharing/repositories/sharing_repository.dart';
import '../../sharing/widgets/qr_scanner_screen.dart';
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
        builder: (_) => ScenarioTheme(
          child: ScenarioDetailScreen(
            repository: widget.repository,
            scenarioId: scenario.id,
            currentSelection: _selection,
          ),
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

  Future<void> _importScenarioSheet() async {
    final imported = await showModalBottomSheet<List<Scenario>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ImportScenarioSheet(repository: widget.repository),
    );
    if (!mounted || imported == null || imported.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã nhận ${imported.length} kịch bản (“${imported.first.title}”).',
        ),
      ),
    );
    await _openDetail(imported.first);
  }

  Future<void> _addBackground() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: ScenarioRepository.audioTypeGroups,
      );
      if (file == null) return;
      final path = await widget.repository.importAudioFile(file);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ScenarioRepository.importErrorMessage(error))),
      );
    }
  }

  Widget _filterChip(ScenarioFilter filter, String label) {
    final selected = _filter == filter;
    final palette = ScenarioPalette.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = filter),
      showCheckmark: false,
      backgroundColor: palette.card,
      selectedColor: palette.chipSelected,
      labelStyle: TextStyle(
        color: selected ? palette.onChipSelected : palette.text,
        fontWeight: FontWeight.w600,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : palette.outline,
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
    final palette = ScenarioPalette.of(context);
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
                        IconButton.outlined(
                          tooltip: 'Nhận kịch bản bằng mã / QR',
                          onPressed: _importScenarioSheet,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          tooltip: 'Thêm kịch bản',
                          style: IconButton.styleFrom(
                            backgroundColor: palette.yellow,
                            foregroundColor: palette.onYellow,
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
                        fillColor: palette.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: palette.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: palette.outline),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Không tìm thấy kịch bản phù hợp.',
                      style: TextStyle(color: palette.muted),
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
                    Text(
                      'ÂM THANH NỀN',
                      style: TextStyle(
                        color: palette.muted,
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
                              foregroundColor: palette.muted,
                              side: BorderSide(color: palette.outline),
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
                    Text(
                      'Âm thanh mẫu được tạo để thử giao diện. Bạn có thể thêm file MP3, M4A hoặc WAV của mình.',
                      style: TextStyle(color: palette.muted, fontSize: 12),
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

class _ImportScenarioSheet extends StatefulWidget {
  const _ImportScenarioSheet({required this.repository});
  final ScenarioRepository repository;

  @override
  State<_ImportScenarioSheet> createState() => _ImportScenarioSheetState();
}

class _ImportScenarioSheetState extends State<_ImportScenarioSheet> {
  final _codeCtrl = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (result != null && mounted) {
      _codeCtrl.text = result;
      await _submitCode();
    }
  }

  Future<void> _submitCode() async {
    final raw = _codeCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã chia sẻ hoặc quét QR.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final sharingRepo = SharingRepository(FileService());
      List<Scenario> importedScenarios = const [];

      if (raw.toUpperCase().contains('TRON1.')) {
        final ComboPackage pkg = sharingRepo.decodeCode(raw);
        importedScenarios = _extractScenarios(pkg);
      } else {
        final onlineCode = BackupService.normalizeOnlineCode(raw);
        if (onlineCode != null) {
          final api =
              widget.repository.api ?? ApiClient(storage: StorageService());
          Map<String, dynamic> res;
          if (onlineCode.startsWith('MKT-')) {
            final list = await api.getList('/market/packages');
            Map<String, dynamic>? found;
            for (final item in list) {
              final map = Map<String, dynamic>.from(item as Map);
              if ((map['code'] as String? ?? '').toUpperCase() == onlineCode) {
                found = map;
                break;
              }
            }
            if (found == null) {
              throw const FormatException(
                'Không tìm thấy gói kịch bản với mã này.',
              );
            }
            res = found;
          } else {
            res = await api.postJson('/shares/$onlineCode/import', {});
          }
          importedScenarios = _extractScenariosFromServerMap(res);
        } else {
          final ComboPackage pkg = sharingRepo.decodeCode(raw);
          importedScenarios = _extractScenarios(pkg);
        }
      }

      if (importedScenarios.isEmpty) {
        throw const FormatException(
          'Mã chia sẻ này không chứa kịch bản hội thoại nào.',
        );
      }

      for (final sc in importedScenarios) {
        await widget.repository.saveUserScenario(
          sc.copyWith(source: ScenarioSource.user),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(importedScenarios);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FormatException
              ? e.message
              : e is ApiException
              ? e.message
              : 'Mã chia sẻ không hợp lệ hoặc không tải được kịch bản.';
          _isBusy = false;
        });
      }
    }
  }

  List<Scenario> _extractScenarios(ComboPackage pkg) {
    if (pkg.scenarios.isNotEmpty) {
      return pkg.scenarios;
    }
    final result = <Scenario>[];
    for (final c in pkg.combos) {
      final found = widget.repository.findScenario(c.scenarioId);
      if (found != null) {
        result.add(
          found.copyWith(
            id: 'user-${DateTime.now().microsecondsSinceEpoch}-${result.length}',
            title: '${found.title} (${c.name})',
            source: ScenarioSource.user,
          ),
        );
      }
    }
    return result;
  }

  List<Scenario> _extractScenariosFromServerMap(Map<String, dynamic> res) {
    final rawScenarios = (res['customScenarios'] as List?) ?? const [];
    final scenarios = <Scenario>[];
    for (final rawSc in rawScenarios) {
      final map = Map<String, dynamic>.from(rawSc as Map);
      final sc = Scenario.fromJson(map);
      final steps = sc.steps
          .map(
            (st) => DialogueStep(
              id: st.id,
              type: st.type,
              text: st.text,
              audioPath:
                  st.audioPath != null &&
                      ScenarioRepository.isBundledAudio(st.audioPath!)
                  ? st.audioPath
                  : null,
              seconds: st.seconds,
            ),
          )
          .toList();
      scenarios.add(sc.copyWith(source: ScenarioSource.user, steps: steps));
    }
    if (scenarios.isNotEmpty) return scenarios;

    final rawCombos = (res['combos'] as List?) ?? const [];
    for (final rawCombo in rawCombos) {
      final map = Map<String, dynamic>.from(rawCombo as Map);
      final scenarioId = map['scenarioId'] as String?;
      if (scenarioId == null) continue;
      final found = widget.repository.findScenario(scenarioId);
      if (found != null) {
        scenarios.add(
          found.copyWith(
            id: 'user-${DateTime.now().microsecondsSinceEpoch}-${scenarios.length}',
            title: '${found.title} (${map['name'] ?? 'Bạn bè'})',
            source: ScenarioSource.user,
          ),
        );
      }
    }
    return scenarios;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhận kịch bản từ bạn bè',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Quét mã QR hoặc nhập mã chia sẻ (EH-XXXXXX, MKT-XXXXXX, TRON1.…) để lưu kịch bản vào máy.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : _scanQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Quét mã QR từ máy bạn bè'),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mã chia sẻ kịch bản',
                hintText: 'Nhập mã EH-XXXXXX hoặc dán mã TRON1.…',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isBusy ? null : _submitCode,
                icon: _isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_done_rounded),
                label: Text(_isBusy ? 'Đang tải kịch bản...' : 'Nhận kịch bản'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
