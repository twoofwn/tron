import '../../scenario/repositories/scenario_repository.dart' as legacy;
import '../models/scenario.dart';
import 'scenario_repository.dart';

/// Thông tin tối thiểu mà combo, cuộc gọi giả và chia sẻ cần từ một kịch bản.
class ScenarioInfo {
  const ScenarioInfo({
    required this.id,
    required this.title,
    required this.caller,
    required this.dialogue,
  });

  final String id;
  final String title;
  final String caller;
  final String dialogue;
}

/// Cầu nối giữa ID kịch bản cũ trong combo đã lưu và kho kịch bản mới.
abstract final class ScenarioLookup {
  static const legacyIds = {
    'boss': 'boss-server',
    'mother': 'mother-urgent',
    'friend': 'friend-lan-demo',
  };

  /// ID kịch bản có sẵn trong `assets/scenarios/scenarios.json`.
  static const bundledIds = {
    'mother-urgent',
    'boss-server',
    'landlord-rent',
    'friend-lan-demo',
  };

  static String canonicalId(String id) => legacyIds[id] ?? id;

  /// ID có thể nhập từ gói chia sẻ. Kịch bản cá nhân gắn với file trên máy
  /// nên không được chia sẻ.
  static bool isShareableId(String id) =>
      bundledIds.contains(canonicalId(id)) ||
      legacy.ScenarioRepository.scenarios.any((item) => item.id == id);

  static ScenarioInfo resolve(String id, ScenarioRepository? library) {
    final scenario = library?.findScenario(canonicalId(id));
    if (scenario != null) return _fromScenario(scenario);
    final old = legacy.ScenarioRepository.find(id);
    return ScenarioInfo(
      id: old.id,
      title: old.title,
      caller: old.caller,
      dialogue: old.dialogue,
    );
  }

  static ScenarioInfo _fromScenario(Scenario scenario) => ScenarioInfo(
    id: scenario.id,
    title: scenario.title,
    caller: scenario.callerName,
    dialogue: scenario.steps
        .where((step) => step.type == DialogueStepType.speech)
        .map((step) => step.text)
        .join(' '),
  );
}
