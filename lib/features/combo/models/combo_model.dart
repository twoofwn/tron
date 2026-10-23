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
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (id.isEmpty || name.trim().isEmpty || name.length > 80) {
      throw const FormatException('Tên combo không hợp lệ.');
    }
    final backgrounds = (json['backgroundSoundPaths'] as List).cast<String>();
    if (backgrounds.any(
      (key) => !BackgroundSound.values.any((sound) => sound.name == key),
    )) {
      throw const FormatException('Âm thanh nền không hợp lệ.');
    }
    return ComboModel(
      id: id,
      name: name,
      scenarioId: json['scenarioId'] as String,
      callInterface: CallInterface.values.byName(
        json['callInterface'] as String,
      ),
      ringtoneType: RingtoneType.values.byName(json['ringtoneType'] as String),
      ringtonePath: json['ringtonePath'] as String?,
      backgroundSoundPaths: List.unmodifiable(backgrounds),
      customBackgroundPath: json['customBackgroundPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
