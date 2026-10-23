enum ScenarioCategory { family, work, personal }

enum ScenarioSource { builtIn, sampleUser, user }

enum DialogueStepType { speech, wait }

class DialogueStep {
  const DialogueStep({
    required this.id,
    required this.type,
    required this.text,
    this.audioPath,
    this.seconds = 0,
  });

  final String id;
  final DialogueStepType type;
  final String text;
  final String? audioPath;
  final int seconds;

  DialogueStep copyWith({String? text, String? audioPath, int? seconds}) =>
      DialogueStep(
        id: id,
        type: type,
        text: text ?? this.text,
        audioPath: audioPath ?? this.audioPath,
        seconds: seconds ?? this.seconds,
      );

  factory DialogueStep.fromJson(Map<String, dynamic> json) => DialogueStep(
    id: json['id'] as String,
    type: DialogueStepType.values.byName(json['type'] as String),
    text: json['text'] as String,
    audioPath: json['audioPath'] as String?,
    seconds: json['seconds'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    if (audioPath != null) 'audioPath': audioPath,
    'seconds': seconds,
  };
}

class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    required this.callerName,
    required this.initial,
    this.estimatedSeconds,
    required this.defaultBackgroundId,
    required this.steps,
  });

  final String id;
  final String title;
  final ScenarioCategory category;
  final ScenarioSource source;
  final String callerName;
  final String initial;
  final int? estimatedSeconds;
  final String? defaultBackgroundId;
  final List<DialogueStep> steps;

  int get speechCount =>
      steps.where((step) => step.type == DialogueStepType.speech).length;

  int get speechSeconds => steps.fold(
    0,
    (total, step) =>
        total + (step.type == DialogueStepType.speech ? step.seconds : 0),
  );

  int get estimatedCallSeconds =>
      estimatedSeconds ??
      speechSeconds +
          steps.where((step) => step.type == DialogueStepType.wait).length * 12;

  String get categoryLabel => switch (category) {
    ScenarioCategory.family => 'Gia đình',
    ScenarioCategory.work => 'Công việc',
    ScenarioCategory.personal => 'Cá nhân',
  };

  bool get isEditable => source == ScenarioSource.user;

  Scenario copyWith({
    String? id,
    String? title,
    ScenarioCategory? category,
    ScenarioSource? source,
    String? callerName,
    String? initial,
    int? estimatedSeconds,
    String? defaultBackgroundId,
    List<DialogueStep>? steps,
  }) => Scenario(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    source: source ?? this.source,
    callerName: callerName ?? this.callerName,
    initial: initial ?? this.initial,
    estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
    defaultBackgroundId: defaultBackgroundId ?? this.defaultBackgroundId,
    steps: steps ?? this.steps,
  );

  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
    id: json['id'] as String,
    title: json['title'] as String,
    category: ScenarioCategory.values.byName(json['category'] as String),
    source: ScenarioSource.values.byName(json['source'] as String),
    callerName: json['callerName'] as String,
    initial: json['initial'] as String,
    estimatedSeconds: json['estimatedSeconds'] as int?,
    defaultBackgroundId: json['defaultBackgroundId'] as String?,
    steps: (json['steps'] as List<dynamic>)
        .map((step) => DialogueStep.fromJson(step as Map<String, dynamic>))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'source': source.name,
    'callerName': callerName,
    'initial': initial,
    if (estimatedSeconds != null) 'estimatedSeconds': estimatedSeconds,
    'defaultBackgroundId': defaultBackgroundId,
    'steps': steps.map((step) => step.toJson()).toList(),
  };
}

class AmbientSound {
  const AmbientSound({
    required this.id,
    required this.title,
    required this.iconName,
    required this.audioPath,
    this.isCustom = false,
  });

  final String id;
  final String title;
  final String iconName;
  final String audioPath;
  final bool isCustom;

  factory AmbientSound.fromJson(Map<String, dynamic> json) => AmbientSound(
    id: json['id'] as String,
    title: json['title'] as String,
    iconName: json['iconName'] as String? ?? 'music',
    audioPath: json['audioPath'] as String,
    isCustom: json['isCustom'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'iconName': iconName,
    'audioPath': audioPath,
    'isCustom': isCustom,
  };
}

class ScenarioSelection {
  const ScenarioSelection({
    required this.scenarioId,
    required this.backgroundId,
    this.backgroundVolume = 0.3,
    this.backgroundOverridden = false,
  });

  final String scenarioId;
  final String? backgroundId;
  final double backgroundVolume;
  final bool backgroundOverridden;

  ScenarioSelection copyWith({
    String? scenarioId,
    String? backgroundId,
    bool clearBackground = false,
    double? backgroundVolume,
    bool? backgroundOverridden,
  }) => ScenarioSelection(
    scenarioId: scenarioId ?? this.scenarioId,
    backgroundId: clearBackground ? null : backgroundId ?? this.backgroundId,
    backgroundVolume: backgroundVolume ?? this.backgroundVolume,
    backgroundOverridden: backgroundOverridden ?? this.backgroundOverridden,
  );
}
