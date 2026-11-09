import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../models/combo_model.dart';

class ComboRepository {
  ComboRepository(this.storage, {this.api, this.files});
  final StorageService storage;
  final ApiClient? api;

  /// Dùng để đồng bộ giọng tự thu, video tự quay và ảnh đại diện với server;
  /// `null` thì bỏ qua.
  final FileService? files;

  /// Gửi trong `voiceMediaId`/`videoMediaId` để báo server xoá giọng/video.
  static const clearVoiceId = '00000000-0000-0000-0000-000000000000';
  static const _key = AppConfig.combosKey;

  Future<List<ComboModel>>? _loading;

  /// Mã lỗi server nghĩa là file bị từ chối hẳn (thử lại cũng không qua).
  static const _rejectedCodes = {
    'MEDIA_TOO_LARGE',
    'QUOTA_EXCEEDED',
    'MEDIA_INVALID_EXTENSION',
    'MEDIA_SIGNATURE_MISMATCH',
    'MEDIA_EMPTY_OR_CORRUPT',
  };
  String? _uploadRejection;

  /// Lý do server từ chối file ở lần tải lên gần nhất (ví dụ vượt hạn mức),
  /// để báo cho người dùng; đọc xong thì xoá.
  String? takeUploadRejection() {
    final message = _uploadRejection;
    _uploadRejection = null;
    return message;
  }

  /// Chỉ chạy một lần tải tại một thời điểm; lần gọi chồng lên dùng chung kết quả,
  /// tránh lần tải cũ ghi đè danh sách mới hơn.
  Future<List<ComboModel>> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<List<ComboModel>> _load() async {
    if (api != null && await api!.hasToken()) {
      try {
        return await _loadFromServer();
      } catch (_) {
        // Fallback to local cache if server is temporarily unreachable
      }
    }

    final stored = await _readLocal();
    if (stored != null) {
      return stored;
    }
    final initial = [
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-333333333333',
        name: 'Người yêu gọi',
        scenarioId: 'friend',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-222222222222',
        name: 'Bố gọi',
        scenarioId: 'mother',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
        backgroundSoundPaths: const ['television'],
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-111111111111',
        name: 'Anh trai gọi (Tình huống đường vắng)',
        scenarioId: 'boss',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
        backgroundSoundPaths: const ['traffic'],
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-444444444444',
        name: 'Chủ nợ gọi',
        scenarioId: 'debt-collector',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-555555555555',
        name: 'Có người lạ vào trọ',
        scenarioId: 'stranger-at-home',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-666666666666',
        name: 'Bạn đến đón',
        scenarioId: 'friend-pickup',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
      ),
    ];
    await save(initial);
    return initial;
  }

  Future<List<ComboModel>> _loadFromServer() async {
    final remoteList = await api!.getList('/combos');
    final local = {
      for (final combo in await _readLocal() ?? const <ComboModel>[])
        ensureGuid(combo.id): combo,
    };
    final combos = <ComboModel>[];
    final onServer = <String>{};
    for (final map in remoteList) {
      var remote = fromServerMap(map);
      final mine = local[ensureGuid(remote.id)];
      onServer.add(ensureGuid(remote.id));
      // Đổi trên máy mà server chưa nhận: giữ nguyên bản trên máy.
      if (mine != null && mine.syncPending) {
        combos.add(mine);
        continue;
      }
      // Server bản cũ chưa có loại cuộc gọi: giữ loại đang dùng trên máy.
      if (mine != null && !map.containsKey('callType')) {
        remote = remote.copyWith(callType: mine.callType);
      }
      // Server bản cũ chưa có tên người gọi / cách kết thúc video: giữ bản trên máy.
      if (mine != null && !map.containsKey('callerName')) {
        remote = remote.copyWith(
          callerName: mine.callerName,
          videoEndAction: mine.videoEndAction,
        );
      }
      for (final track in MediaTrack.values) {
        remote = await _mergeTrack(
          track,
          remote,
          mine,
          _serverMediaId(map, track),
        );
      }
      combos.add(remote);
    }
    // Combo tạo/sửa trên máy mà chưa gửi được thì server chưa có: giữ lại.
    combos.addAll(
      local.entries
          .where((e) => e.value.syncPending && !onServer.contains(e.key))
          .map((e) => e.value),
    );
    // Combo chỉ bị bỏ vì server không có (ví dụ sao lưu lúc đăng ký bị lỗi):
    // không xoá file của nó, để còn khôi phục được.
    final dropped = {
      for (final entry in local.entries)
        if (!onServer.contains(entry.key) && !entry.value.syncPending)
          ...entry.value.customMediaPaths,
    };
    await save(combos, keepFiles: dropped);

    // Gửi lại các thay đổi chưa tới được server (ví dụ lúc trước mất mạng).
    var changed = false;
    for (var i = 0; i < combos.length; i++) {
      if (!combos[i].syncPending) {
        continue;
      }
      try {
        final synced = await upsertRemote(combos[i]);
        if (synced != null) {
          combos[i] = synced;
          changed = true;
        }
      } catch (_) {
        // Vẫn chưa gửi được: giữ cờ chờ, lần tải sau thử lại.
      }
    }
    if (changed) {
      await save(combos);
    }
    return combos;
  }

  /// Chọn giọng (hoặc video) cho một combo khi gộp danh sách từ server với bản
  /// trên máy. `serverId` là file server đang giữ; id trên máy là file máy này
  /// đồng bộ lần cuối. Hai id khác nhau nghĩa là máy khác đã đổi file.
  /// `merged` là combo đang gộp (bắt đầu từ bản server, chưa có file riêng).
  Future<ComboModel> _mergeTrack(
    MediaTrack track,
    ComboModel merged,
    ComboModel? local,
    String? serverId,
  ) async {
    // Combo chỉ có trên server (ví dụ đăng nhập trên máy mới): lấy file về.
    if (local == null) {
      return _withServerMedia(track, merged, serverId);
    }
    final localPath = track.pathOf(local);
    final syncedId = track.mediaIdOf(local)?.toLowerCase();
    // Dữ liệu từ bản app cũ: có file nhưng chưa từng đồng bộ → giữ và gửi lên.
    if (localPath != null && syncedId == null) {
      return track.put(merged, localPath, null).copyWith(syncPending: true);
    }
    if (serverId == syncedId &&
        localPath != null &&
        await _hasFile(localPath)) {
      return track.put(merged, localPath, syncedId);
    }
    // Máy khác đã đổi/xoá file, hoặc file trên máy bị mất: theo bản trên server.
    return _withServerMedia(track, merged, serverId, fallback: local);
  }

  Future<ComboModel> _withServerMedia(
    MediaTrack track,
    ComboModel merged,
    String? serverId, {
    ComboModel? fallback,
  }) async {
    if (serverId == null) {
      return merged;
    }
    final path = await _download(track, serverId);
    if (path != null) {
      return track.put(merged, path, serverId);
    }
    // Tải về lỗi: giữ file cũ trên máy (nếu có), lần tải sau thử lại.
    final keep = fallback == null ? null : track.pathOf(fallback);
    return keep == null
        ? merged
        : track.put(merged, keep, track.mediaIdOf(fallback!));
  }

  static String? _serverMediaId(Map<String, dynamic> map, MediaTrack track) {
    final id = (map[track.field] as String?)?.toLowerCase();
    return id == null || id == clearVoiceId ? null : id;
  }

  Future<bool> _hasFile(String path) async =>
      files == null || await files!.hasAudio(path);

  Future<List<ComboModel>?> _readLocal() async {
    final value = await storage.read(_key);
    if (value == null) {
      return null;
    }
    return (jsonDecode(value) as List)
        .map(
          (item) => ComboModel.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
  }

  /// Lưu danh sách, rồi xoá các file giọng/video tự thu không còn combo nào dùng
  /// (bị thay, bị xoá, hoặc combo bị xoá). Combo nhân bản dùng chung file
  /// nên chỉ xoá khi không còn combo nào trỏ tới.
  Future<void> save(
    List<ComboModel> combos, {
    Set<String> keepFiles = const {},
  }) async {
    final before = files == null ? null : await _readLocal();
    await storage.write(
      _key,
      jsonEncode(combos.map((combo) => combo.toJson()).toList()),
    );
    if (before == null) {
      return;
    }
    final inUse = {
      ...keepFiles,
      for (final combo in combos) ...combo.customMediaPaths,
    };
    final old = {for (final combo in before) ...combo.recordedMediaPaths};
    for (final path in old.difference(inUse)) {
      await files!.deleteAudio(path);
    }
  }

  /// Gửi combo lên server. Trả về combo đã đánh dấu đồng bộ giọng và video, hoặc
  /// `null` nếu chưa đăng nhập hay file chưa gửi được (sẽ thử lại ở lần tải sau).
  Future<ComboModel?> upsertRemote(ComboModel combo) async {
    if (api == null || !await api!.hasToken()) return null;
    final payload = toServerMap(combo);
    if (files == null) {
      await api!.postJson('/combos', payload);
      return combo.copyWith(syncPending: false);
    }
    var ids = await _trackIds(combo, reuse: true);
    _putIds(payload, ids);
    try {
      await api!.postJson('/combos', payload);
    } on ApiException catch (error) {
      // File đã đồng bộ trước đây không còn trên server: tải lên lại một lần.
      final reused = MediaTrack.values.any(
        (t) => t.pathOf(combo) != null && t.mediaIdOf(combo) != null,
      );
      if (!reused || error.errorCode != 'MEDIA_NOT_FOUND') {
        rethrow;
      }
      ids = await _trackIds(combo, reuse: false);
      _putIds(payload, ids);
      await api!.postJson('/combos', payload);
    }
    if (ids.values.contains(null)) {
      return null;
    }
    var synced = combo.copyWith(syncPending: false);
    for (final track in MediaTrack.values) {
      synced = track.put(synced, track.pathOf(combo), ids[track]);
    }
    return synced;
  }

  /// Id gửi lên cho từng loại file: [clearVoiceId] khi không có file, id cũ khi
  /// file chưa đổi (form bỏ id khi thu lại/xoá), hoặc id sau khi tải lên.
  /// `null` nghĩa là tải lên lỗi.
  Future<Map<MediaTrack, String?>> _trackIds(
    ComboModel combo, {
    required bool reuse,
  }) async => {
    for (final track in MediaTrack.values)
      track: switch (track.pathOf(combo)) {
        null => clearVoiceId,
        final path =>
          (reuse ? track.mediaIdOf(combo) : null) ??
              await uploadMedia(path, track.kind),
      },
  };

  /// Tải file lên lỗi thì không gửi trường đó, để server giữ bản cũ.
  static void _putIds(
    Map<String, dynamic> payload,
    Map<MediaTrack, String?> ids,
  ) {
    for (final MapEntry(key: track, value: id) in ids.entries) {
      payload.remove(track.field);
      if (id != null) {
        payload[track.field] = id;
      }
    }
  }

  /// Tải giọng tự thu lên server (dùng lại file đã có nếu trùng nội dung).
  /// Trả về id trên server, hoặc `null` nếu lỗi.
  Future<String?> uploadVoice(String path) =>
      uploadMedia(path, MediaTrack.voice.kind);

  /// Tải file riêng (giọng: `Voice`, video: `Video`, ảnh: `Image`) lên server, dùng lại file
  /// đã có nếu trùng nội dung. Trả về id trên server, hoặc `null` nếu lỗi.
  Future<String?> uploadMedia(String path, String kind) async {
    if (api == null || files == null) {
      return null;
    }
    try {
      final bytes = await files!.readMedia(path);
      final hash = sha256.convert(bytes).toString();
      final check = await api!.postJson('/media/check', {
        'sha256List': [hash],
      });
      final existing = (check['existing'] as List?) ?? const [];
      if (existing.isNotEmpty) {
        return (existing.first as Map)['mediaId'] as String;
      }
      final uploaded = await api!.uploadMultipart(
        '/media',
        fileName: path.substring('media:'.length),
        bytes: bytes,
        kind: kind,
      );
      return uploaded['mediaId'] as String;
    } on ApiException catch (error) {
      if (_rejectedCodes.contains(error.errorCode)) {
        _uploadRejection = error.message;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tải file từ server về máy; lỗi thì combo dùng giọng máy đọc / tắt camera.
  Future<String?> _download(MediaTrack track, String mediaId) async {
    if (files == null || mediaId == clearVoiceId) {
      return null;
    }
    try {
      return await files!.storeMedia(
        await api!.getBytes('/media/$mediaId'),
        track.extension,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteRemote(String id) async {
    if (api == null || !await api!.hasToken()) return;
    await api!.delete('/combos/$id');
  }

  static String ensureGuid(String rawId) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRegex.hasMatch(rawId)) {
      return rawId.toLowerCase();
    }
    final bytes = md5.convert(utf8.encode('tron-combo:$rawId')).bytes;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Map<String, dynamic> toServerMap(ComboModel combo) => {
    'id': ensureGuid(combo.id),
    'name': combo.name,
    'scenarioId': combo.scenarioId,
    'callInterface': combo.callInterface.name,
    'callType': combo.callType.name,
    'callerName': combo.callerName,
    'videoEndAction': combo.videoEndAction.name,
    'ringtoneType': combo.ringtoneType == RingtoneType.custom
        ? RingtoneType.interfaceDefault.name
        : combo.ringtoneType.name,
    'ringtoneMediaId': null,
    'backgroundSoundIds': combo.backgroundSoundPaths,
    'customBackgroundMediaId': null,
    'backgroundVolume': 0.3,
    'backgroundOverridden': false,
    'createdAt': combo.createdAt.toUtc().toIso8601String(),
  };

  static ComboModel fromServerMap(Map<String, dynamic> map) {
    final bgList = ((map['backgroundSoundIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .where(
          (key) => BackgroundSound.values.any(
            (sound) => sound.name.toLowerCase() == key.toLowerCase(),
          ),
        )
        .toList();
    final callInterfaceStr = (map['callInterface'] as String? ?? 'phone')
        .toLowerCase();
    final callInterface = CallInterface.values.firstWhere(
      (e) => e.name.toLowerCase() == callInterfaceStr,
      orElse: () => CallInterface.phone,
    );
    final ringtoneTypeStr =
        (map['ringtoneType'] as String? ?? 'interfaceDefault').toLowerCase();
    final ringtoneType = RingtoneType.values.firstWhere(
      (e) => e.name.toLowerCase() == ringtoneTypeStr,
      orElse: () => RingtoneType.interfaceDefault,
    );
    final callTypeStr = (map['callType'] as String? ?? '').toLowerCase();
    final callType = CallType.values.firstWhere(
      (e) => e.name == callTypeStr,
      orElse: () => CallType.voice,
    );
    return ComboModel(
      id:
          (map['id'] as String?) ??
          'combo-${DateTime.now().microsecondsSinceEpoch}',
      name: (map['name'] as String?) ?? 'Combo',
      scenarioId: (map['scenarioId'] as String?) ?? 'mother',
      callInterface: callInterface,
      ringtoneType: ringtoneType,
      callType: callType,
      callerName: ComboModel.cleanCallerName(map['callerName']),
      videoEndAction: VideoEndAction.parse(map['videoEndAction']),
      backgroundSoundPaths: bgList,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Các file riêng của combo (giọng tự thu, video tự quay, ảnh đại diện), đồng
/// bộ với server theo cùng một cách: không gửi trường = server giữ nguyên,
/// [ComboRepository.clearVoiceId] = xoá.
enum MediaTrack {
  voice('voiceMediaId', 'Voice', 'wav'),
  video('videoMediaId', 'Video', 'mp4'),

  /// Đuôi lưu bản tải về chỉ để chọn cách lưu: [FileService.storeImage] đặt
  /// đuôi `jpg`/`png` theo nội dung ảnh.
  avatar('avatarMediaId', 'Image', 'jpg');

  const MediaTrack(this.field, this.kind, this.extension);

  /// Tên trường id trên server.
  final String field;

  /// Loại file khi tải lên `/media`.
  final String kind;

  /// Đuôi file khi lưu bản tải về.
  final String extension;

  String? pathOf(ComboModel combo) => switch (this) {
    voice => combo.voicePath,
    video => combo.videoPath,
    avatar => combo.avatarPath,
  };

  String? mediaIdOf(ComboModel combo) => switch (this) {
    voice => combo.voiceMediaId,
    video => combo.videoMediaId,
    avatar => combo.avatarMediaId,
  };

  /// Gán file cho combo: `path` null thì bỏ file; `mediaId` null thì file chưa
  /// có trên server.
  ComboModel put(ComboModel combo, String? path, String? mediaId) =>
      switch (this) {
        voice =>
          path == null
              ? combo.copyWith(clearVoice: true)
              : combo.copyWith(
                  voicePath: path,
                  voiceMediaId: mediaId,
                  clearVoiceMediaId: mediaId == null,
                ),
        video =>
          path == null
              ? combo.copyWith(clearVideo: true)
              : combo.copyWith(
                  videoPath: path,
                  videoMediaId: mediaId,
                  clearVideoMediaId: mediaId == null,
                ),
        avatar =>
          path == null
              ? combo.copyWith(clearAvatar: true)
              : combo.copyWith(
                  avatarPath: path,
                  avatarMediaId: mediaId,
                  clearAvatarMediaId: mediaId == null,
                ),
      };
}
