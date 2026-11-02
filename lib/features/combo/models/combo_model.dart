import 'dart:convert';

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
    this.voicePath,
    this.voiceMediaId,
    this.callType = CallType.voice,
    this.videoPath,
    this.videoMediaId,
    this.syncPending = false,
  });
  final String id;
  final String name;
  final String scenarioId;
  final CallInterface callInterface;
  final RingtoneType ringtoneType;
  final String? ringtonePath;
  final List<String> backgroundSoundPaths;
  final String? customBackgroundPath;

  /// Giọng người gọi do người dùng tự thu (`media:UUID.wav`). Có giọng này thì
  /// cuộc gọi phát nó thay cho giọng máy đọc kịch bản.
  final String? voicePath;

  /// Id trên server của giọng đang dùng, lần đồng bộ gần nhất trên máy này.
  /// Chỉ có nghĩa với tài khoản đang đăng nhập; không đi theo khi chia sẻ.
  final String? voiceMediaId;

  /// Gọi thoại hay gọi video.
  final CallType callType;

  /// Video người gọi do người dùng tự quay (`media:UUID.mp4`). Cuộc gọi video
  /// phát video này kèm camera trước của người dùng; không có thì người gọi
  /// như đang tắt camera và cuộc gọi phát giọng như gọi thoại.
  final String? videoPath;

  /// Id trên server của video đang dùng, giống [voiceMediaId].
  final String? videoMediaId;

  /// Combo đã đổi trên máy (kể cả giọng) nhưng server chưa nhận, ví dụ do mất
  /// mạng. Khi còn cờ này, bản trên máy được ưu tiên và app gửi lại lên server.
  final bool syncPending;
  final DateTime createdAt;

  ComboModel copyWith({
    String? id,
    String? name,
    String? ringtonePath,
    String? customBackgroundPath,
    String? voicePath,
    String? voiceMediaId,
    CallType? callType,
    String? videoPath,
    String? videoMediaId,
    bool? syncPending,
    bool clearVoice = false,
    bool clearVoiceMediaId = false,
    bool clearVideo = false,
    bool clearVideoMediaId = false,
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
    voicePath: stripCustomAudio || clearVoice
        ? null
        : voicePath ?? this.voicePath,
    voiceMediaId: stripCustomAudio || clearVoice || clearVoiceMediaId
        ? null
        : voiceMediaId ?? this.voiceMediaId,
    callType: callType ?? this.callType,
    videoPath: stripCustomAudio || clearVideo
        ? null
        : videoPath ?? this.videoPath,
    videoMediaId: stripCustomAudio || clearVideo || clearVideoMediaId
        ? null
        : videoMediaId ?? this.videoMediaId,
    syncPending: stripCustomAudio ? false : syncPending ?? this.syncPending,
  );

  /// Bỏ thông tin đồng bộ của tài khoản này (khi chia sẻ, nhập, sao chép):
  /// combo nhận về sẽ tự tải giọng và video lên tài khoản của người nhận.
  ComboModel withoutSync() => copyWith(
    clearVoiceMediaId: true,
    clearVideoMediaId: true,
    syncPending: true,
  );

  /// So nội dung combo, bỏ qua thông tin đồng bộ.
  bool sameContentAs(ComboModel other) {
    Map<String, Object?> content(ComboModel combo) => combo.toJson()
      ..remove('voiceMediaId')
      ..remove('videoMediaId')
      ..remove('syncPending');
    return jsonEncode(content(this)) == jsonEncode(content(other));
  }

  /// Mọi file riêng của combo: chuông, âm nền, giọng thu và video tự quay.
  List<String> get customMediaPaths => [
    ?ringtonePath,
    ?customBackgroundPath,
    ?voicePath,
    ?videoPath,
  ];

  /// File do người dùng tự thu/quay; app tự xoá khi không còn combo nào dùng.
  List<String> get recordedMediaPaths => [?voicePath, ?videoPath];

  bool get isVideoCall => callType == CallType.video;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scenarioId': scenarioId,
    'callInterface': callInterface.name,
    'ringtoneType': ringtoneType.name,
    'ringtonePath': ringtonePath,
    'backgroundSoundPaths': backgroundSoundPaths,
    'customBackgroundPath': customBackgroundPath,
    'voicePath': voicePath,
    'voiceMediaId': voiceMediaId,
    'callType': callType.name,
    'videoPath': videoPath,
    'videoMediaId': videoMediaId,
    'syncPending': syncPending,
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

    final callType = CallType.values.firstWhere(
      (v) => v.name == (json['callType'] ?? '').toString().toLowerCase().trim(),
      orElse: () => CallType.voice,
    );

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
      voicePath: json['voicePath'] as String?,
      voiceMediaId: json['voiceMediaId'] as String?,
      callType: callType,
      videoPath: json['videoPath'] as String?,
      videoMediaId: json['videoMediaId'] as String?,
      syncPending: json['syncPending'] as bool? ?? false,
      createdAt: createdAt,
    );
  }
}
