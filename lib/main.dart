import 'package:flutter/material.dart';

import 'features/scenarios/data/scenario_repository.dart';
import 'features/scenarios/models/scenario.dart';
import 'features/scenarios/presentation/scenario_library_screen.dart';
import 'features/scenarios/presentation/scenario_palette.dart';

void main() => runApp(const TronApp());

class TronApp extends StatelessWidget {
  const TronApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Trốn',
    debugShowCheckedModeBanner: false,
    theme: ScenarioPalette.theme,
    home: const ScenarioDemoHome(),
  );
}

class ScenarioDemoHome extends StatefulWidget {
  const ScenarioDemoHome({super.key, this.repository});

  final ScenarioRepository? repository;

  @override
  State<ScenarioDemoHome> createState() => _ScenarioDemoHomeState();
}

class _ScenarioDemoHomeState extends State<ScenarioDemoHome> {
  late final ScenarioRepository _repository =
      widget.repository ?? ScenarioRepository();
  late Future<void> _loading = _repository.load();
  ScenarioSelection _selection = const ScenarioSelection(
    scenarioId: 'mother-urgent',
    backgroundId: 'television',
  );

  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Future<void> _openLibrary() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ScenarioLibraryScreen(
          repository: _repository,
          initialSelection: _selection,
          onSelectionChanged: (selection) {
            if (mounted) setState(() => _selection = selection);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Không tải được kho kịch bản.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _loading = _repository.load()),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final selected = _repository.findScenario(_selection.scenarioId);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRỐN',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ScenarioPalette.yellow,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kho kịch bản',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Điểm vào tạm để kiểm tra màn 5 và 6. Kịch bản bạn chọn sẽ trở về bản nháp combo ở đây.',
                  style: TextStyle(color: ScenarioPalette.muted, height: 1.4),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: ScenarioPalette.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KỊCH BẢN ĐANG CHỌN',
                        style: TextStyle(color: ScenarioPalette.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selected?.title ?? 'Chưa chọn',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _openLibrary,
                    child: const Text('Mở kho kịch bản'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
