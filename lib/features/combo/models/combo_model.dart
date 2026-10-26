import '../../../shared/enums/call_interface.dart';

class ComboModel {
  const ComboModel({
    required this.id,
    required this.name,
    required this.scenarioId,
    required this.callInterface,
    required this.createdAt,
    this.ringtoneType = RingtoneType.interfaceDefault,
    this.ringtonePath,
    this.backgroundSoundPaths = const [],
    this.customBackgroundPath,
  });
  final String id;
  final String name;
  final String scenarioId;
  final CallInterface callInterface;
  final RingtoneType ringtoneType;
  final String? ringtonePath;
  final List<String> backgroundSoundPaths;
  final String? customBackgroundPath;
  final DateTime createdAt;

  ComboModel copyWith({
    String? id,
    String? name,
    String? ringtonePath,
    String? customBackgroundPath,
    bool stripCustomAudio = false,
  }) => ComboModel(
    id: id ?? this.id,
    name: name ?? this.name,
    scenarioId: scenarioId,
    callInterface: callInterface,
    createdAt: createdAt,
    ringtoneType: stripCustomAudio && ringtoneType == RingtoneType.custom
        ? RingtoneType.interfaceDefault
        : ringtoneType,
    ringtonePath: stripCustomAudio ? null : ringtonePath ?? this.ringtonePath,
    backgroundSoundPaths: backgroundSoundPaths,
    customBackgroundPath: stripCustomAudio
        ? null
        : customBackgroundPath ?? this.customBackgroundPath,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scenarioId': scenarioId,
    'callInterface': callInterface.name,
    'ringtoneType': ringtoneType.name,
    'ringtonePath': ringtonePath,
    'backgroundSoundPaths': backgroundSoundPaths,
    'customBackgroundPath': customBackgroundPath,
    'createdAt': createdAt.toIso8601String(),
  };
  factory ComboModel.fromJson(Map<String, Object?> json) {
    final id =
        json['id'] as String? ??
        'combo-${DateTime.now().microsecondsSinceEpoch}';
    final name = (json['name'] as String? ?? 'Combo').trim();
    if (name.isEmpty) {
      throw const FormatException('Tên combo không hợp lệ.');
    }

    final rawBg = json['backgroundSoundPaths'] ?? json['backgroundSoundIds'];
    final List<String> backgrounds = [];
    if (rawBg is List) {
      for (final item in rawBg) {
        if (item != null) {
          final s = item.toString().trim();
          if (s.isNotEmpty) backgrounds.add(s == 'car' ? 'traffic' : s);
        }
      }
    }

    final rawInterface = (json['callInterface'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final callInterface =
        CallInterface.values.cast<CallInterface?>().firstWhere(
          (v) => v?.name.toLowerCase() == rawInterface,
          orElse: () => CallInterface.zalo,
        ) ??
        CallInterface.zalo;

    final rawRingtone = (json['ringtoneType'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final ringtoneType =
        RingtoneType.values.cast<RingtoneType?>().firstWhere(
          (v) => v?.name.toLowerCase() == rawRingtone,
          orElse: () => RingtoneType.interfaceDefault,
        ) ??
        RingtoneType.interfaceDefault;

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt'] as String);
    } catch (_) {
      createdAt = DateTime.now();
    }

    return ComboModel(
      id: id,
      name: name,
      scenarioId: json['scenarioId'] as String? ?? 'boss',
      callInterface: callInterface,
      ringtoneType: ringtoneType,
      ringtonePath: json['ringtonePath'] as String?,
      backgroundSoundPaths: List.unmodifiable(backgrounds),
      customBackgroundPath: json['customBackgroundPath'] as String?,
      createdAt: createdAt,
    );
  }
}
