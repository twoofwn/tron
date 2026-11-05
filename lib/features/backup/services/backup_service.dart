import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers/theme_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../../auth/providers/auth_provider.dart';
import '../../combo/models/combo_model.dart';
import '../../combo/providers/combo_provider.dart';
import '../../combo/repositories/combo_repository.dart';
import '../../scenarios/models/scenario.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../../sharing/models/combo_package.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});

class BackupStatusInfo {
  const BackupStatusInfo({
    this.lastBackupAt,
    this.deviceName,
    this.comboCount = 0,
    this.scenarioCount = 0,
    this.ambientCount = 0,
    this.mediaCount = 0,
    this.totalMediaBytes = 0,
    this.quotaMediaBytes = AppConfig.defaultQuotaMediaBytes,
  });

  final DateTime? lastBackupAt;
  final String? deviceName;
  final int comboCount;
  final int scenarioCount;
  final int ambientCount;
  final int mediaCount;
  final int totalMediaBytes;
  final int quotaMediaBytes;

  factory BackupStatusInfo.fromJson(Map<String, dynamic> json) =>
      BackupStatusInfo(
        lastBackupAt: json['lastBackupAt'] != null
            ? DateTime.tryParse(json['lastBackupAt'] as String)
            : null,
        deviceName: json['deviceName'] as String?,
        comboCount: (json['comboCount'] as num?)?.toInt() ?? 0,
        scenarioCount: (json['scenarioCount'] as num?)?.toInt() ?? 0,
        ambientCount: (json['ambientCount'] as num?)?.toInt() ?? 0,
        mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
        totalMediaBytes: (json['totalMediaBytes'] as num?)?.toInt() ?? 0,
        quotaMediaBytes:
            (json['quotaMediaBytes'] as num?)?.toInt() ??
            AppConfig.defaultQuotaMediaBytes,
      );
}

class BackupService {
  BackupService(this.ref);
  final Ref ref;

  Future<BackupStatusInfo> fetchStatus() async {
    final json = await ref.read(apiClientProvider).getJson('/backup/status');
    return BackupStatusInfo.fromJson(json);
  }

  /// Uploads any missing local audio files and saves a full backup snapshot on the server.
  Future<BackupStatusInfo> performBackup({bool reuseVoiceIds = true}) async {
    final api = ref.read(apiClientProvider);
    if (!await api.hasToken()) {
      throw const FormatException('Chưa đăng nhập tài khoản.');
    }
    final files = ref.read(fileServiceProvider);
    final combos = await ref.read(comboListProvider.future);
    final scenarioRepo = await ref.read(scenarioLibraryProvider.future);
    final themeMode = await ref.read(themeModeProvider.future);

    final userScenarios = scenarioRepo.scenarios
        .where((s) => s.source == ScenarioSource.user)
        .toList();
    final customAmbients = scenarioRepo.backgrounds
        .where((b) => b.isCustom)
        .toList();

    // Map local audio paths -> uploaded server mediaId
    final pathToMediaId = <String, String>{};

    Future<String?> ensureUploaded(String? path, String kind) async {
      if (path == null || path.isEmpty) return null;
      if (pathToMediaId.containsKey(path)) return pathToMediaId[path];

      Uint8List? bytes;
      var fileName = 'audio.mp3';
      try {
        if (path.startsWith('media:')) {
          bytes = await files.readMedia(path);
          fileName = path.substring(6);
        }
      } catch (_) {
        return null;
      }
      if (bytes == null || bytes.isEmpty) return null;

      final hash = sha256.convert(bytes).toString();
      final checkJson = await api.postJson('/media/check', {
        'sha256List': [hash],
      });
      final existing = (checkJson['existing'] as List?) ?? const [];
      if (existing.isNotEmpty) {
        final mediaId = (existing.first as Map)['mediaId'] as String;
        pathToMediaId[path] = mediaId;
        return mediaId;
      }

      final uploaded = await api.uploadMultipart(
        '/media',
        fileName: fileName,
        bytes: bytes,
        kind: kind,
      );
      final mediaId = uploaded['mediaId'] as String;
      pathToMediaId[path] = mediaId;
      return mediaId;
    }

    final comboPayloads = <Map<String, dynamic>>[];
    for (final combo in combos) {
      final ringMediaId = combo.ringtoneType == RingtoneType.custom
          ? await ensureUploaded(combo.ringtonePath, 'Ringtone')
          : null;
      final bgMediaId = await ensureUploaded(
        combo.customBackgroundPath,
        'Ambient',
      );
      // Không có giọng → báo server xoá; tải lên lỗi → null để server giữ bản cũ.
      final voiceMediaId = combo.voicePath == null
          ? ComboRepository.clearVoiceId
          : (reuseVoiceIds ? combo.voiceMediaId : null) ??
                await ensureUploaded(combo.voicePath, 'Voice');
      final videoMediaId = combo.videoPath == null
          ? ComboRepository.clearVoiceId
          : (reuseVoiceIds ? combo.videoMediaId : null) ??
                await ensureUploaded(combo.videoPath, 'Video');
      final avatarMediaId = combo.avatarPath == null
          ? ComboRepository.clearVoiceId
          : (reuseVoiceIds ? combo.avatarMediaId : null) ??
                await ensureUploaded(combo.avatarPath, 'Image');

      comboPayloads.add({
        'id': combo.id,
        'name': combo.name,
        'scenarioId': combo.scenarioId,
        'callInterface': combo.callInterface.name,
        'ringtoneType':
            ringMediaId == null && combo.ringtoneType == RingtoneType.custom
            ? RingtoneType.interfaceDefault.name
            : combo.ringtoneType.name,
        'ringtoneMediaId': ringMediaId,
        'backgroundSoundIds': combo.backgroundSoundPaths,
        'customBackgroundMediaId': bgMediaId,
        'voiceMediaId': voiceMediaId,
        'callType': combo.callType.name,
        'callerName': combo.callerName,
        'videoEndAction': combo.videoEndAction.name,
        'videoMediaId': videoMediaId,
        'avatarMediaId': avatarMediaId,
        'backgroundVolume': 0.3,
        'backgroundOverridden': false,
        'createdAt': combo.createdAt.toUtc().toIso8601String(),
      });
    }

    final scenarioPayloads = <Map<String, dynamic>>[];
    for (final sc in userScenarios) {
      final stepPayloads = <Map<String, dynamic>>[];
      for (final st in sc.steps) {
        stepPayloads.add({
          'id': st.id,
          'type': st.type.name,
          'text': st.text,
          'audioPath': st.audioPath,
          'mediaFileId': null,
          'seconds': st.seconds,
        });
      }
      scenarioPayloads.add({
        'id': sc.id,
        'title': sc.title,
        'category': sc.category.name,
        'source': 'user',
        'callerName': sc.callerName,
        'initial': sc.initial,
        'estimatedSeconds': sc.estimatedSeconds,
        'defaultBackgroundId': sc.defaultBackgroundId,
        'isPro': false,
        'steps': stepPayloads,
      });
    }

    final ambientPayloads = customAmbients
        .map(
          (a) => {
            'id': a.id,
            'title': a.title,
            'iconName': a.iconName,
            'audioPath': a.audioPath,
            'mediaFileId': null,
            'legacyKey': null,
            'isCustom': true,
          },
        )
        .toList();

    final Map<String, dynamic> statusJson;
    try {
      statusJson = await api.putJson('/backup', {
        'deviceName': 'TRỐN Flutter App',
        'appVersion': '1.0.0',
        'settings': {
          'themeMode': themeMode.name,
          'defaultCallDelaySeconds': 30,
        },
        'customAmbientSounds': ambientPayloads,
        'customScenarios': scenarioPayloads,
        'combos': comboPayloads,
      });
    } on ApiException catch (error) {
      // Id giọng/video lưu trên máy đã bị server dọn: tải lên lại rồi thử một lần nữa.
      if (reuseVoiceIds && error.errorCode == 'MEDIA_NOT_FOUND') {
        return performBackup(reuseVoiceIds: false);
      }
      rethrow;
    }

    await ref.read(authStateProvider.notifier).refreshProfile();
    return BackupStatusInfo.fromJson(statusJson);
  }

  /// Downloads the backup snapshot and media files from server and restores local combos/scenarios.
  Future<int> restoreFromServer() async {
    final api = ref.read(apiClientProvider);
    final files = ref.read(fileServiceProvider);
    final scenarioRepo = await ref.read(scenarioLibraryProvider.future);

    final data = await api.getJson('/backup');
    final mediaList = (data['mediaFiles'] as List?) ?? const [];
    final mediaIdToExt = <String, String>{};
    for (final item in mediaList) {
      final map = Map<String, dynamic>.from(item as Map);
      mediaIdToExt[map['mediaId'] as String] =
          (map['extension'] as String?) ?? 'mp3';
    }

    final mediaIdToLocalPath = <String, String>{};
    Future<String?> downloadMedia(String? mediaId) async {
      if (mediaId == null || mediaId.isEmpty) return null;
      if (mediaIdToLocalPath.containsKey(mediaId)) {
        return mediaIdToLocalPath[mediaId];
      }
      final ext = mediaIdToExt[mediaId] ?? 'mp3';
      final bytes = await api.getBytes('/media/$mediaId');
      final storedPath = await files.storeMedia(
        bytes,
        ext == 'm4a' ? 'mp3' : ext,
      );
      mediaIdToLocalPath[mediaId] = storedPath;
      return storedPath;
    }

    final customScenarios = (data['customScenarios'] as List?) ?? const [];
    for (final rawSc in customScenarios) {
      final map = Map<String, dynamic>.from(rawSc as Map);
      final scenario = Scenario.fromJson(map);
      if (scenario.source == ScenarioSource.user) {
        await scenarioRepo.saveUserScenario(scenario);
      }
    }

    final rawCombos = (data['combos'] as List?) ?? const [];
    final restoredCombos = <ComboModel>[];
    for (final raw in rawCombos) {
      final map = Map<String, dynamic>.from(raw as Map);
      final ringPath = await downloadMedia(map['ringtoneMediaId'] as String?);
      final customBgPath = await downloadMedia(
        map['customBackgroundMediaId'] as String?,
      );
      final rawVoiceId = map['voiceMediaId'] as String?;
      final voiceMediaId = rawVoiceId == ComboRepository.clearVoiceId
          ? null
          : rawVoiceId;
      final voicePath = await downloadMedia(voiceMediaId);
      final rawVideoId = map['videoMediaId'] as String?;
      final videoMediaId = rawVideoId == ComboRepository.clearVoiceId
          ? null
          : rawVideoId;
      final videoPath = await downloadMedia(videoMediaId);
      final rawAvatarId = map['avatarMediaId'] as String?;
      final avatarMediaId = rawAvatarId == ComboRepository.clearVoiceId
          ? null
          : rawAvatarId;
      final avatarPath = await downloadMedia(avatarMediaId);
      final bgList = ((map['backgroundSoundIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .where(
            (key) => BackgroundSound.values.any((sound) => sound.name == key),
          )
          .toList();

      restoredCombos.add(
        ComboModel(
          id: map['id'] as String,
          name: map['name'] as String,
          scenarioId: map['scenarioId'] as String,
          callInterface: CallInterface.values.byName(
            map['callInterface'] as String,
          ),
          ringtoneType: RingtoneType.values.byName(
            map['ringtoneType'] as String,
          ),
          ringtonePath: ringPath,
          backgroundSoundPaths: bgList,
          customBackgroundPath: customBgPath,
          voicePath: voicePath,
          voiceMediaId: voicePath == null ? null : voiceMediaId,
          callType: _callType(map['callType']),
          callerName: ComboModel.cleanCallerName(map['callerName']),
          videoEndAction: VideoEndAction.parse(map['videoEndAction']),
          videoPath: videoPath,
          videoMediaId: videoPath == null ? null : videoMediaId,
          avatarPath: avatarPath,
          avatarMediaId: avatarPath == null ? null : avatarMediaId,
          createdAt:
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }

    if (restoredCombos.isNotEmpty) {
      await ref.read(comboRepositoryProvider).save(restoredCombos);
      ref.invalidate(comboListProvider);
    }
    return restoredCombos.length;
  }

  static CallType _callType(Object? raw) => CallType.values.firstWhere(
    (type) => type.name == raw,
    orElse: () => CallType.voice,
  );

  /// Creates an online share code `EH-XXXXXX` on the server.
  Future<String> createOnlineShare(
    List<ComboModel> selectedCombos, {
    required bool includeAudio,
  }) async {
    final api = ref.read(apiClientProvider);
    if (!await api.hasToken()) {
      throw const FormatException('Chưa đăng nhập tài khoản.');
    }
    await performBackup();

    final repository = ref.read(comboRepositoryProvider);
    final comboDtos = <Map<String, dynamic>>[];
    for (final c in selectedCombos) {
      // Kèm giọng tự thu khi người dùng chọn chia sẻ cả âm thanh.
      final voicePath = c.voicePath;
      final voiceMediaId = !includeAudio || voicePath == null
          ? null
          : c.voiceMediaId ?? await repository.uploadVoice(voicePath);
      final videoPath = c.videoPath;
      final videoMediaId = !includeAudio || videoPath == null
          ? null
          : c.videoMediaId ??
                await repository.uploadMedia(videoPath, MediaTrack.video.kind);
      // Ảnh đại diện luôn đi theo combo, kể cả khi không kèm âm thanh.
      final avatarPath = c.avatarPath;
      final avatarMediaId = avatarPath == null
          ? null
          : c.avatarMediaId ??
                await repository.uploadMedia(
                  avatarPath,
                  MediaTrack.avatar.kind,
                );
      comboDtos.add({
        'id': c.id,
        'name': c.name,
        'scenarioId': c.scenarioId,
        'callInterface': c.callInterface.name,
        'ringtoneType': c.ringtoneType.name,
        'ringtoneMediaId': null,
        'backgroundSoundIds': c.backgroundSoundPaths,
        'customBackgroundMediaId': null,
        'voiceMediaId': voiceMediaId,
        'callType': c.callType.name,
        'callerName': c.callerName,
        'videoEndAction': c.videoEndAction.name,
        'videoMediaId': videoMediaId,
        'avatarMediaId': avatarMediaId,
        'backgroundVolume': 0.3,
        'backgroundOverridden': false,
        'createdAt': c.createdAt.toUtc().toIso8601String(),
      });
    }

    final res = await api.postJson('/shares', {
      'combos': comboDtos,
      'customScenarios': const <Map<String, dynamic>>[],
      'customAmbientSounds': const <Map<String, dynamic>>[],
      'includeAudio': includeAudio,
      'expiresInDays': 7,
    });

    return res['code'] as String;
  }

  /// Fetches an online share package by `EH-XXXXXX` code and converts it into a local `ComboPackage`.
  Future<ComboPackage> fetchOnlineSharePackage(String code) async {
    final api = ref.read(apiClientProvider);
    final shareCode = code.trim();
    final res = await api.postJson('/shares/$shareCode/import', {});
    final rawCombos = (res['combos'] as List?) ?? const [];
    final audio = <String, Uint8List>{};
    final combos = <ComboModel>[];
    for (final raw in rawCombos) {
      final map = Map<String, dynamic>.from(raw as Map);
      // Giọng tự thu đi kèm gói: tải về, gói nhập sẽ lưu thành file trên máy.
      String? voicePath;
      final voiceId = map['voiceMediaId'] as String?;
      if (voiceId != null && voiceId != ComboRepository.clearVoiceId) {
        try {
          final bytes = await api.getBytes('/shares/$shareCode/media/$voiceId');
          voicePath = 'media:${const Uuid().v4()}.wav';
          audio[voicePath] = bytes;
        } catch (_) {
          // Không tải được giọng: combo dùng giọng máy đọc.
        }
      }
      // Video người gọi đi kèm gói (khi chia sẻ cả âm thanh và video).
      String? videoPath;
      final videoId = map['videoMediaId'] as String?;
      if (videoId != null && videoId != ComboRepository.clearVoiceId) {
        try {
          final bytes = await api.getBytes('/shares/$shareCode/media/$videoId');
          videoPath = 'media:${const Uuid().v4()}.mp4';
          audio[videoPath] = bytes;
        } catch (_) {
          // Không tải được video: cuộc gọi video hiện như người gọi tắt camera.
        }
      }
      // Ảnh đại diện người gọi: lưu theo đúng loại ảnh (JPG/PNG).
      String? avatarPath;
      final avatarId = map['avatarMediaId'] as String?;
      if (avatarId != null && avatarId != ComboRepository.clearVoiceId) {
        try {
          final bytes = await api.getBytes(
            '/shares/$shareCode/media/$avatarId',
          );
          final extension = FileService.imageExtension(bytes);
          if (extension != null) {
            avatarPath = 'media:${const Uuid().v4()}.$extension';
            audio[avatarPath] = bytes;
          }
        } catch (_) {
          // Không tải được ảnh: hiện chữ cái đầu.
        }
      }
      final bgList = ((map['backgroundSoundIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .where(
            (key) => BackgroundSound.values.any((sound) => sound.name == key),
          )
          .toList();
      combos.add(
        ComboModel(
          id: map['id'] as String,
          name: map['name'] as String,
          scenarioId: map['scenarioId'] as String,
          callInterface: CallInterface.values.byName(
            map['callInterface'] as String,
          ),
          ringtoneType: RingtoneType.values.byName(
            map['ringtoneType'] as String,
          ),
          backgroundSoundPaths: bgList,
          voicePath: voicePath,
          callType: _callType(map['callType']),
          callerName: ComboModel.cleanCallerName(map['callerName']),
          videoEndAction: VideoEndAction.parse(map['videoEndAction']),
          videoPath: videoPath,
          avatarPath: avatarPath,
          createdAt:
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }

    return ComboPackage(
      id: (res['code'] as String? ?? 'EH-ONLINE').replaceFirst('EH-', ''),
      combos: combos,
      audio: audio,
    );
  }
}
