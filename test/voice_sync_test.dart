import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/config/app_config.dart';
import 'package:tron/core/network/api_client.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/storage_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/providers/combo_provider.dart';
import 'package:tron/features/combo/repositories/combo_repository.dart';
import 'package:tron/features/sharing/repositories/sharing_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

Uint8List wav(int fill) => Uint8List.fromList(List.filled(44 + 22050, fill));

/// Video MP4 giả: 4 byte độ dài rồi "ftyp", phần sau đổi theo `fill`.
Uint8List mp4(int fill) => Uint8List.fromList([
  0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, //
  ...List.filled(64, fill),
]);

/// Ảnh JPG giả: 3 byte đầu FF D8 FF, phần sau đổi theo `fill`.
Uint8List jpg(int fill) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(32, fill)]);

/// Âm thanh lưu trong bộ nhớ thay cho thư mục của app.
class MemoryFiles extends FileService {
  final audio = <String, Uint8List>{};
  final deleted = <String>[];
  var _next = 0;
  @override
  Future<Uint8List> readMedia(String path) async =>
      audio[path] ?? (throw StateError('missing $path'));
  @override
  Future<String> storeAudio(Uint8List bytes, String extension) async {
    final path = 'media:local-${_next++}.$extension';
    audio[path] = bytes;
    return path;
  }

  @override
  Future<String> storeVideo(Uint8List bytes) async {
    final path = 'media:local-${_next++}.mp4';
    audio[path] = bytes;
    return path;
  }

  @override
  Future<String> storeImage(Uint8List bytes) async {
    final path = 'media:local-${_next++}.${FileService.imageExtension(bytes)}';
    audio[path] = bytes;
    return path;
  }

  @override
  Future<bool> hasAudio(String path) async => audio.containsKey(path);
  @override
  Future<void> deleteAudio(String path) async {
    audio.remove(path);
    deleted.add(path);
  }
}

/// Server giả: giữ combo và file âm thanh của một tài khoản.
class FakeServer {
  final combos = <String, Map<String, dynamic>>{};
  final media = <String, Uint8List>{};
  final posted = <Map<String, dynamic>>[];
  var uploads = 0;
  final uploadKinds = <String>[];
  var downloads = 0;
  var listCalls = 0;
  var failDownloads = false;
  var offline = false;

  /// Lỗi server trả về khi tải file lên, ví dụ `QUOTA_EXCEEDED`.
  String? rejectUploads;
  var _next = 1;

  String addMedia(Uint8List bytes) {
    final id =
        'aaaaaaaa-0000-0000-0000-${(_next++).toString().padLeft(12, '0')}';
    media[id] = bytes;
    return id;
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  late final client = MockClient((request) async {
    if (offline) {
      throw http.ClientException('offline');
    }
    final path = request.url.path.replaceFirst('/api/v1', '');
    if (path == '/combos' && request.method == 'GET') {
      listCalls++;
      return _json(combos.values.toList());
    }
    if (path == '/combos' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      posted.add(body);
      final stored = {...body};
      // Cùng quy ước cho giọng và video: thiếu = giữ, clearVoiceId = xoá.
      for (final field in ['voiceMediaId', 'videoMediaId', 'avatarMediaId']) {
        final value = body[field] as String?;
        if (value != null &&
            value != ComboRepository.clearVoiceId &&
            !media.containsKey(value)) {
          return _json({'errorCode': 'MEDIA_NOT_FOUND'}, 400);
        }
        if (!body.containsKey(field)) {
          stored[field] = combos[body['id']]?[field];
        } else if (value == ComboRepository.clearVoiceId) {
          stored[field] = null;
        }
      }
      combos[body['id'] as String] = stored;
      return _json(stored);
    }
    if (path == '/media/check') {
      final hashes = (jsonDecode(request.body)['sha256List'] as List)
          .cast<String>();
      final existing = [
        for (final entry in media.entries)
          if (hashes.contains(sha256.convert(entry.value).toString()))
            {'mediaId': entry.key},
      ];
      return _json({'existing': existing});
    }
    if (path == '/media' && request.method == 'POST') {
      if (rejectUploads != null) {
        return _json({
          'errorCode': rejectUploads,
          'detail': 'Đã vượt hạn mức lưu trữ âm thanh (200 MB).',
        }, 400);
      }
      uploads++;
      final form = latin1.decode(request.bodyBytes);
      final isVideo = form.contains('\r\n\r\nVideo\r\n');
      final isImage = form.contains('\r\n\r\nImage\r\n');
      uploadKinds.add(
        isVideo
            ? 'Video'
            : isImage
            ? 'Image'
            : 'Voice',
      );
      return _json({
        'mediaId': addMedia(
          isVideo
              ? mp4(uploads)
              : isImage
              ? jpg(uploads)
              : wav(uploads),
        ),
      });
    }
    if (path.startsWith('/media/')) {
      downloads++;
      final bytes = media[path.substring('/media/'.length)];
      if (failDownloads || bytes == null) {
        return _json({'errorCode': 'MEDIA_NOT_FOUND'}, 404);
      }
      return http.Response.bytes(bytes, 200);
    }
    return _json({'errorCode': 'NOT_FOUND'}, 404);
  });
}

void main() {
  late StorageService storage;
  late MemoryFiles files;
  late FakeServer server;
  late ComboRepository repository;
  final id = ComboRepository.ensureGuid('c');

  ComboModel combo({
    String? voicePath,
    String? voiceMediaId,
    String? videoPath,
    String? videoMediaId,
    String? avatarPath,
    String? avatarMediaId,
    bool pending = false,
  }) => ComboModel(
    id: id,
    name: 'Mẹ',
    scenarioId: 'mother',
    callInterface: CallInterface.phone,
    createdAt: DateTime(2026),
    voicePath: voicePath,
    voiceMediaId: voiceMediaId,
    callType: videoPath == null && videoMediaId == null
        ? CallType.voice
        : CallType.video,
    videoPath: videoPath,
    videoMediaId: videoMediaId,
    avatarPath: avatarPath,
    avatarMediaId: avatarMediaId,
    syncPending: pending,
  );

  void serverHas(String? voiceMediaId) => server.combos[id] = {
    ...ComboRepository.toServerMap(combo()),
    'voiceMediaId': voiceMediaId,
  };

  Future<void> deviceHas(ComboModel value) async =>
      ComboRepository(storage).save([value]);

  setUp(() {
    SharedPreferences.setMockInitialValues({AppConfig.accessTokenKey: 'token'});
    storage = StorageService();
    files = MemoryFiles();
    server = FakeServer();
    repository = ComboRepository(
      storage,
      api: ApiClient(
        storage: storage,
        httpClient: server.client,
        baseUrl: 'http://x',
      ),
      files: files,
    );
  });

  test('Data saved by an older app version (no sync fields) still loads', () {
    final legacy = ComboModel.fromJson({
      'id': id,
      'name': 'Mẹ',
      'scenarioId': 'mother',
      'callInterface': 'phone',
      'voicePath': 'media:0f0f.wav',
      'createdAt': '2026-01-01T00:00:00.000',
    });
    expect(legacy.voicePath, 'media:0f0f.wav');
    expect(legacy.voiceMediaId, isNull);
    expect(legacy.syncPending, isFalse);
  });

  test('A voice recorded before this update is kept and uploaded', () async {
    files.audio['media:old.wav'] = wav(9);
    await deviceHas(combo(voicePath: 'media:old.wav'));
    serverHas(null);
    final loaded = (await repository.load()).single;
    expect(loaded.voicePath, 'media:old.wav');
    expect(loaded.syncPending, isFalse);
    expect(server.uploads, 1);
    expect(server.combos[id]!['voiceMediaId'], loaded.voiceMediaId);
  });

  test('Unchanged voice is kept and not downloaded again', () async {
    final remoteId = server.addMedia(wav(1));
    files.audio['media:mine.wav'] = wav(1);
    await deviceHas(combo(voicePath: 'media:mine.wav', voiceMediaId: remoteId));
    serverHas(remoteId);
    final loaded = (await repository.load()).single;
    expect(loaded.voicePath, 'media:mine.wav');
    expect(server.downloads, 0);
  });

  test(
    'Voice deleted on another device is removed here, file deleted',
    () async {
      final remoteId = server.addMedia(wav(1));
      files.audio['media:mine.wav'] = wav(1);
      await deviceHas(
        combo(voicePath: 'media:mine.wav', voiceMediaId: remoteId),
      );
      serverHas(null);
      final loaded = (await repository.load()).single;
      expect(loaded.voicePath, isNull);
      expect(files.deleted, ['media:mine.wav']);
    },
  );

  test('Voice re-recorded on another device replaces the one here', () async {
    final oldId = server.addMedia(wav(1));
    final newId = server.addMedia(wav(2));
    files.audio['media:mine.wav'] = wav(1);
    await deviceHas(combo(voicePath: 'media:mine.wav', voiceMediaId: oldId));
    serverHas(newId);
    final loaded = (await repository.load()).single;
    expect(loaded.voiceMediaId, newId);
    expect(files.audio[loaded.voicePath], wav(2));
    expect(files.deleted, ['media:mine.wav']);
  });

  test('Voice deleted here while offline is not brought back', () async {
    final remoteId = server.addMedia(wav(1));
    await deviceHas(combo(pending: true));
    serverHas(remoteId);
    final loaded = (await repository.load()).single;
    expect(loaded.voicePath, isNull);
    expect(loaded.syncPending, isFalse);
    expect(server.posted.last['voiceMediaId'], ComboRepository.clearVoiceId);
    expect(server.combos[id]!['voiceMediaId'], isNull);
    expect(server.downloads, 0);
  });

  test('Voice re-recorded here while offline wins over the server', () async {
    final remoteId = server.addMedia(wav(1));
    files.audio['media:new.wav'] = wav(5);
    await deviceHas(combo(voicePath: 'media:new.wav', pending: true));
    serverHas(remoteId);
    final loaded = (await repository.load()).single;
    expect(loaded.voicePath, 'media:new.wav');
    expect(loaded.voiceMediaId, isNot(remoteId));
    expect(server.combos[id]!['voiceMediaId'], loaded.voiceMediaId);
  });

  test('A lost local file is downloaded again', () async {
    final remoteId = server.addMedia(wav(3));
    await deviceHas(combo(voicePath: 'media:gone.wav', voiceMediaId: remoteId));
    serverHas(remoteId);
    final loaded = (await repository.load()).single;
    expect(files.audio[loaded.voicePath], wav(3));
  });

  test('A failed download keeps the current voice and retries later', () async {
    final oldId = server.addMedia(wav(1));
    final newId = server.addMedia(wav(2));
    files.audio['media:mine.wav'] = wav(1);
    await deviceHas(combo(voicePath: 'media:mine.wav', voiceMediaId: oldId));
    serverHas(newId);
    server.failDownloads = true;
    final first = (await repository.load()).single;
    expect(first.voicePath, 'media:mine.wav');
    expect(first.voiceMediaId, oldId);
    server.failDownloads = false;
    final second = (await repository.load()).single;
    expect(second.voiceMediaId, newId);
  });

  test(
    'Saving a synced voice reuses its id; a missing server copy is re-uploaded',
    () async {
      final remoteId = server.addMedia(wav(1));
      files.audio['media:mine.wav'] = wav(1);
      final synced = await repository.upsertRemote(
        combo(voicePath: 'media:mine.wav', voiceMediaId: remoteId),
      );
      expect(server.uploads, 0);
      expect(synced!.voiceMediaId, remoteId);

      server.media.remove(remoteId);
      final again = await repository.upsertRemote(
        combo(voicePath: 'media:mine.wav', voiceMediaId: remoteId),
      );
      expect(server.uploads, 1);
      expect(again!.voiceMediaId, isNot(remoteId));
      expect(server.combos[id]!['voiceMediaId'], again.voiceMediaId);
    },
  );

  test(
    'A failed upload leaves the server voice untouched and stays pending',
    () async {
      final remoteId = server.addMedia(wav(1));
      serverHas(remoteId);
      final result = await repository.upsertRemote(
        combo(voicePath: 'media:unreadable.wav', pending: true),
      );
      expect(result, isNull);
      expect(server.posted.last.containsKey('voiceMediaId'), isFalse);
      expect(server.combos[id]!['voiceMediaId'], remoteId);
    },
  );

  test(
    'Saving the list deletes voice files no combo uses, keeps shared ones',
    () async {
      files.audio['media:a.wav'] = wav(1);
      files.audio['media:b.wav'] = wav(2);
      final local = ComboRepository(storage, files: files);
      final a = combo(voicePath: 'media:a.wav');
      final copy = a.copyWith(id: 'copy');
      final b = combo(voicePath: 'media:b.wav').copyWith(id: 'b');
      await local.save([a, copy, b]);
      await local.save([copy, b.copyWith(clearVoice: true)]);
      expect(files.audio.containsKey('media:a.wav'), isTrue);
      expect(files.deleted, ['media:b.wav']);
    },
  );

  test('Shared packages never carry this account sync ids', () async {
    files.audio['media:a.wav'] = wav(1);
    final sharing = SharingRepository(files);
    final package = await sharing.create([
      combo(
        voicePath: 'media:a.wav',
        voiceMediaId: 'aaaaaaaa-0000-0000-0000-000000000009',
      ),
    ], includeAudio: true);
    final json = jsonDecode(utf8.decode(sharing.encode(package))) as Map;
    expect((json['combos'] as List).single['voiceMediaId'], isNull);
    final imported = (await sharing.materialize(package, {id})).single;
    expect(imported.voiceMediaId, isNull);
    expect(imported.syncPending, isTrue);
  });

  test('Saving through the app records the synced id on the combo', () async {
    files.audio['media:a.wav'] = wav(4);
    final container = ProviderContainer(
      overrides: [comboRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(comboListProvider.future);
    await container
        .read(comboListProvider.notifier)
        .saveCombo(combo(voicePath: 'media:a.wav', pending: true));
    final saved = (await container.read(comboListProvider.future))
        .firstWhere((item) => item.id == id);
    expect(saved.syncPending, isFalse);
    expect(saved.voiceMediaId, server.combos[id]!['voiceMediaId']);
  });

  test('Offline save keeps the change pending for the next load', () async {
    files.audio['media:a.wav'] = wav(4);
    server.offline = true;
    final container = ProviderContainer(
      overrides: [comboRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(comboListProvider.future);
    await container
        .read(comboListProvider.notifier)
        .saveCombo(combo(voicePath: 'media:a.wav', pending: true));
    final saved = (await container.read(comboListProvider.future))
        .firstWhere((item) => item.id == id);
    expect(saved.syncPending, isTrue);
    server.offline = false;
    final reloaded = (await repository.load()).firstWhere(
      (item) => item.id == id,
    );
    expect(reloaded.syncPending, isFalse);
    expect(server.combos[id]!['voiceMediaId'], reloaded.voiceMediaId);
  });

  test(
    'A combo dropped only because the server lacks it keeps its voice file',
    () async {
      // Ví dụ: sao lưu lúc đăng ký bị lỗi, server chỉ có combo mặc định.
      files.audio['media:mine.wav'] = wav(1);
      await deviceHas(
        combo(
          voicePath: 'media:mine.wav',
          voiceMediaId: 'aaaaaaaa-0000-0000-0000-000000000077',
        ),
      );
      final loaded = await repository.load();
      expect(loaded, isEmpty);
      expect(files.audio.containsKey('media:mine.wav'), isTrue);
      expect(files.deleted, isEmpty);
    },
  );

  test('Overlapping loads share one request so an old load cannot overwrite a newer list', () async {
    serverHas(null);
    final results = await Future.wait([repository.load(), repository.load()]);
    expect(server.listCalls, 1);
    expect(identical(results[0], results[1]), isTrue);
    await repository.load();
    expect(server.listCalls, 2);
  });

  group('Video call', () {
    void serverHasVideo(String? videoMediaId) => server.combos[id] = {
      ...ComboRepository.toServerMap(combo(videoMediaId: videoMediaId)),
      'videoMediaId': videoMediaId,
    };

    test(
      'Saving uploads the video as a Video file and records its id',
      () async {
        files.audio['media:clip.mp4'] = mp4(7);
        final synced = await repository.upsertRemote(
          combo(videoPath: 'media:clip.mp4', pending: true),
        );
        expect(server.uploadKinds, ['Video']);
        expect(server.posted.last['callType'], 'video');
        expect(
          server.posted.last['voiceMediaId'],
          ComboRepository.clearVoiceId,
        );
        expect(synced!.videoMediaId, server.combos[id]!['videoMediaId']);
        expect(synced.syncPending, isFalse);
      },
    );

    test(
      'A file the server refuses is reported once, combo stays pending',
      () async {
        files.audio['media:clip.mp4'] = mp4(7);
        server.rejectUploads = 'QUOTA_EXCEEDED';
        final result = await repository.upsertRemote(
          combo(videoPath: 'media:clip.mp4', pending: true),
        );
        expect(result, isNull);
        expect(repository.takeUploadRejection(), contains('hạn mức'));
        expect(repository.takeUploadRejection(), isNull);
      },
    );

    test('Video and voice sync independently on the same combo', () async {
      files.audio['media:a.wav'] = wav(1);
      files.audio['media:clip.mp4'] = mp4(7);
      final synced = await repository.upsertRemote(
        combo(voicePath: 'media:a.wav', videoPath: 'media:clip.mp4'),
      );
      expect(server.uploadKinds, ['Voice', 'Video']);
      expect(synced!.voiceMediaId, isNotNull);
      expect(synced.videoMediaId, isNotNull);
      expect(synced.voiceMediaId, isNot(synced.videoMediaId));
    });

    test('Video recorded on another device is downloaded as MP4', () async {
      final remoteId = server.addMedia(mp4(3));
      serverHasVideo(remoteId);
      final loaded = (await repository.load()).single;
      expect(loaded.callType, CallType.video);
      expect(loaded.videoPath, endsWith('.mp4'));
      expect(files.audio[loaded.videoPath], mp4(3));
      expect(loaded.videoMediaId, remoteId);
    });

    test('Video deleted here tells the server to clear it', () async {
      final remoteId = server.addMedia(mp4(1));
      serverHasVideo(remoteId);
      final result = await repository.upsertRemote(combo(pending: true));
      expect(server.posted.last['videoMediaId'], ComboRepository.clearVoiceId);
      expect(server.combos[id]!['videoMediaId'], isNull);
      expect(result!.videoPath, isNull);
    });

    test(
      'A failed video upload keeps the server video and stays pending',
      () async {
        final remoteId = server.addMedia(mp4(1));
        serverHasVideo(remoteId);
        final result = await repository.upsertRemote(
          combo(videoPath: 'media:unreadable.mp4', pending: true),
        );
        expect(result, isNull);
        expect(server.posted.last.containsKey('videoMediaId'), isFalse);
        expect(server.combos[id]!['videoMediaId'], remoteId);
      },
    );

    test('A video missing on the server is uploaded again', () async {
      final remoteId = server.addMedia(mp4(1));
      files.audio['media:clip.mp4'] = mp4(1);
      server.media.remove(remoteId);
      final again = await repository.upsertRemote(
        combo(videoPath: 'media:clip.mp4', videoMediaId: remoteId),
      );
      expect(server.uploadKinds, ['Video']);
      expect(again!.videoMediaId, isNot(remoteId));
    });

    test('Saving the list deletes video files no combo uses', () async {
      files.audio['media:a.mp4'] = mp4(1);
      final local = ComboRepository(storage, files: files);
      await local.save([combo(videoPath: 'media:a.mp4')]);
      await local.save([
        combo(videoPath: 'media:a.mp4').copyWith(clearVideo: true),
      ]);
      expect(files.deleted, ['media:a.mp4']);
    });

    test(
      'An older server without call type keeps the local call type',
      () async {
        final remoteId = server.addMedia(mp4(1));
        files.audio['media:clip.mp4'] = mp4(1);
        await deviceHas(
          combo(videoPath: 'media:clip.mp4', videoMediaId: remoteId),
        );
        serverHasVideo(remoteId);
        server.combos[id]!.remove('callType');
        final loaded = (await repository.load()).single;
        expect(loaded.callType, CallType.video);
        expect(loaded.videoPath, 'media:clip.mp4');
        expect(server.downloads, 0);
      },
    );
  });

  group('Caller avatar', () {
    void serverHasAvatar(String? avatarMediaId) => server.combos[id] = {
      ...ComboRepository.toServerMap(combo()),
      'avatarMediaId': avatarMediaId,
    };

    test(
      'Saving uploads the photo as an Image file and records its id',
      () async {
        files.audio['media:me.jpg'] = jpg(5);
        final synced = await repository.upsertRemote(
          combo(avatarPath: 'media:me.jpg', pending: true),
        );
        expect(server.uploadKinds, ['Image']);
        expect(synced!.avatarMediaId, server.combos[id]!['avatarMediaId']);
        expect(synced.avatarPath, 'media:me.jpg');
        expect(synced.syncPending, isFalse);
      },
    );

    test('A photo set on another device is downloaded', () async {
      final remoteId = server.addMedia(jpg(3));
      serverHasAvatar(remoteId);
      final loaded = (await repository.load()).single;
      expect(loaded.avatarPath, endsWith('.jpg'));
      expect(files.audio[loaded.avatarPath], jpg(3));
      expect(loaded.avatarMediaId, remoteId);
    });

    test('Removing the photo tells the server to clear it', () async {
      final remoteId = server.addMedia(jpg(1));
      serverHasAvatar(remoteId);
      await repository.upsertRemote(combo(pending: true));
      expect(server.posted.last['avatarMediaId'], ComboRepository.clearVoiceId);
      expect(server.combos[id]!['avatarMediaId'], isNull);
    });

    test('Saving the list deletes photos no combo uses', () async {
      files.audio['media:me.jpg'] = jpg(1);
      final local = ComboRepository(storage, files: files);
      await local.save([combo(avatarPath: 'media:me.jpg')]);
      await local.save([
        combo(avatarPath: 'media:me.jpg').copyWith(clearAvatar: true),
      ]);
      expect(files.deleted, ['media:me.jpg']);
    });

    test('The photo survives JSON and sharing drops only its sync id', () {
      final value = combo(avatarPath: 'media:me.jpg', avatarMediaId: 'srv');
      final restored = ComboModel.fromJson(value.toJson());
      expect(restored.avatarPath, 'media:me.jpg');
      expect(restored.avatarMediaId, 'srv');
      final shared = value.withoutSync();
      expect(shared.avatarPath, 'media:me.jpg');
      expect(shared.avatarMediaId, isNull);
      // Bỏ âm thanh riêng khi chia sẻ vẫn giữ ảnh đại diện.
      expect(value.copyWith(stripCustomAudio: true).avatarPath, 'media:me.jpg');
    });
  });
}
