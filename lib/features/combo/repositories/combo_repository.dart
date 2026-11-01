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

  /// Dùng để đồng bộ giọng tự thu với server; `null` thì bỏ qua phần âm thanh.
  final FileService? files;

  /// Gửi trong `voiceMediaId` để báo server xoá giọng của combo.
  static const clearVoiceId = '00000000-0000-0000-0000-000000000000';
  static const _key = AppConfig.combosKey;

  Future<List<ComboModel>>? _loading;

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
        id: 'f4b5d550-ec19-4d54-a744-111111111111',
        name: 'Sếp gọi gấp',
        scenarioId: 'boss',
        callInterface: CallInterface.zalo,
        createdAt: DateTime(2026),
        backgroundSoundPaths: const ['office'],
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-222222222222',
        name: 'Mẹ gọi về nhà',
        scenarioId: 'mother',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
        ringtoneType: RingtoneType.classic,
        backgroundSoundPaths: const ['television'],
      ),
      ComboModel(
        id: 'f4b5d550-ec19-4d54-a744-333333333333',
        name: 'Lan rủ đi gấp',
        scenarioId: 'friend',
        callInterface: CallInterface.messenger,
        createdAt: DateTime(2026),
        backgroundSoundPaths: const ['traffic', 'cafe'],
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
      final remote = fromServerMap(map);
      onServer.add(ensureGuid(remote.id));
      combos.add(
        await _mergeVoice(
          remote,
          local[ensureGuid(remote.id)],
          _serverVoiceId(map),
        ),
      );
    }
    // Combo tạo/sửa trên máy mà chưa gửi được thì server chưa có: giữ lại.
    combos.addAll(
      local.entries
          .where((e) => e.value.syncPending && !onServer.contains(e.key))
          .map((e) => e.value),
    );
    // Combo chỉ bị bỏ vì server không có (ví dụ sao lưu lúc đăng ký bị lỗi):
    // không xoá file âm thanh của nó, để còn khôi phục được.
    final dropped = {
      for (final entry in local.entries)
        if (!onServer.contains(entry.key) && !entry.value.syncPending)
          ...entry.value.customAudioPaths,
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

  /// Chọn giọng cho một combo khi gộp danh sách từ server với bản trên máy.
  /// `serverVoiceId` là giọng server đang giữ; `voiceMediaId` trên máy là giọng
  /// máy này đồng bộ lần cuối. Hai id khác nhau nghĩa là máy khác đã đổi giọng.
  Future<ComboModel> _mergeVoice(
    ComboModel remote,
    ComboModel? local,
    String? serverVoiceId,
  ) async {
    // Combo chỉ có trên server (ví dụ đăng nhập trên máy mới): lấy giọng về.
    if (local == null) {
      return _withServerVoice(remote, serverVoiceId);
    }
    // Đổi trên máy mà server chưa nhận: giữ nguyên bản trên máy.
    if (local.syncPending) {
      return local;
    }
    final syncedId = local.voiceMediaId?.toLowerCase();
    // Dữ liệu từ bản app cũ: có giọng nhưng chưa từng đồng bộ → giữ và gửi lên.
    if (local.voicePath != null && syncedId == null) {
      return remote.copyWith(voicePath: local.voicePath, syncPending: true);
    }
    if (serverVoiceId == syncedId &&
        local.voicePath != null &&
        await _hasFile(local.voicePath!)) {
      return remote.copyWith(
        voicePath: local.voicePath,
        voiceMediaId: syncedId,
      );
    }
    // Máy khác đã đổi/xoá giọng, hoặc file trên máy bị mất: theo bản trên server.
    return _withServerVoice(remote, serverVoiceId, fallback: local);
  }

  Future<ComboModel> _withServerVoice(
    ComboModel remote,
    String? serverVoiceId, {
    ComboModel? fallback,
  }) async {
    if (serverVoiceId == null) {
      return remote;
    }
    final path = await _downloadVoice(serverVoiceId);
    if (path != null) {
      return remote.copyWith(voicePath: path, voiceMediaId: serverVoiceId);
    }
    // Tải về lỗi: giữ giọng cũ trên máy (nếu có), lần tải sau thử lại.
    final keep = fallback?.voicePath;
    return keep == null
        ? remote
        : remote.copyWith(
            voicePath: keep,
            voiceMediaId: fallback!.voiceMediaId,
          );
  }

  static String? _serverVoiceId(Map<String, dynamic> map) {
    final id = (map['voiceMediaId'] as String?)?.toLowerCase();
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

  /// Lưu danh sách, rồi xoá các file giọng không còn combo nào dùng
  /// (giọng bị thay, bị xoá, hoặc combo bị xoá). Combo nhân bản dùng chung file
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
      for (final combo in combos) ...combo.customAudioPaths,
    };
    final old = {
      for (final combo in before)
        if (combo.voicePath != null) combo.voicePath!,
    };
    for (final path in old.difference(inUse)) {
      await files!.deleteAudio(path);
    }
  }

  /// Gửi combo lên server. Trả về combo đã đánh dấu đồng bộ giọng, hoặc `null`
  /// nếu chưa đăng nhập hay giọng chưa gửi được (sẽ thử lại ở lần tải sau).
  Future<ComboModel?> upsertRemote(ComboModel combo) async {
    if (api == null || !await api!.hasToken()) return null;
    final payload = toServerMap(combo);
    if (files == null) {
      await api!.postJson('/combos', payload);
      return combo.copyWith(syncPending: false);
    }
    final voicePath = combo.voicePath;
    // Giọng đã có trên server (form bỏ id khi thu lại/xoá) thì gửi id, khỏi tải lên lại.
    final reuseId = voicePath != null ? combo.voiceMediaId : null;
    var voiceId = voicePath == null
        ? clearVoiceId
        : reuseId ?? await _uploadVoice(voicePath);
    // Tải giọng lên lỗi thì không gửi trường này, để server giữ bản cũ.
    if (voiceId != null) {
      payload['voiceMediaId'] = voiceId;
    }
    try {
      await api!.postJson('/combos', payload);
    } on ApiException catch (error) {
      // Giọng đã đồng bộ trước đây không còn trên server: tải lên lại một lần.
      if (reuseId == null || error.errorCode != 'MEDIA_NOT_FOUND') {
        rethrow;
      }
      voiceId = await _uploadVoice(voicePath!);
      payload.remove('voiceMediaId');
      if (voiceId != null) {
        payload['voiceMediaId'] = voiceId;
      }
      await api!.postJson('/combos', payload);
    }
    if (voiceId == null) {
      return null;
    }
    return voicePath == null
        ? combo.copyWith(clearVoiceMediaId: true, syncPending: false)
        : combo.copyWith(voiceMediaId: voiceId, syncPending: false);
  }

  /// Tải giọng tự thu lên server (dùng lại file đã có nếu trùng nội dung).
  /// Trả về id trên server, hoặc `null` nếu lỗi.
  Future<String?> uploadVoice(String path) => _uploadVoice(path);

  Future<String?> _uploadVoice(String path) async {
    if (api == null || files == null) {
      return null;
    }
    try {
      final bytes = await files!.readAudio(path);
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
        kind: 'Voice',
      );
      return uploaded['mediaId'] as String;
    } catch (_) {
      return null;
    }
  }

  /// Tải giọng tự thu từ server về máy; lỗi thì để combo dùng giọng máy đọc.
  Future<String?> _downloadVoice(String? mediaId) async {
    if (files == null || mediaId == null || mediaId == clearVoiceId) {
      return null;
    }
    try {
      return await files!.storeAudio(
        await api!.getBytes('/media/$mediaId'),
        'wav',
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
    return ComboModel(
      id:
          (map['id'] as String?) ??
          'combo-${DateTime.now().microsecondsSinceEpoch}',
      name: (map['name'] as String?) ?? 'Combo',
      scenarioId: (map['scenarioId'] as String?) ?? 'mother',
      callInterface: callInterface,
      ringtoneType: ringtoneType,
      backgroundSoundPaths: bgList,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
