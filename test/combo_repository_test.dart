import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/config/app_config.dart';
import 'package:tron/core/network/api_client.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/core/services/voice_recorder.dart';
import 'package:tron/core/services/storage_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/combo/providers/combo_provider.dart';
import 'package:tron/features/combo/repositories/combo_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  voiceSyncTests();
  test(
    'Seeds once, persists edits and preserves an empty collection',
    () async {
      final repository = ComboRepository(StorageService());
      final seeded = await repository.load();
      expect(seeded.length, 3);
      await repository.save([seeded.first.copyWith(name: 'Tên đã sửa')]);
      expect(
        (await ComboRepository(StorageService()).load()).single.name,
        'Tên đã sửa',
      );
      await repository.save([]);
      expect(await repository.load(), isEmpty);
    },
  );
  test(
    'Create, duplicate, import duplicate policy and delete persist',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(comboListProvider.future);
      final notifier = container.read(comboListProvider.notifier);
      final combo = ComboModel(
        id: 'test-combo',
        name: 'Cuộc gọi thử',
        scenarioId: 'boss',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
      );
      await notifier.saveCombo(combo);
      expect(container.read(selectedComboIdProvider), combo.id);
      await notifier.duplicateCombo(combo);
      expect((await container.read(comboListProvider.future)).length, 5);
      expect(await notifier.importCombos([combo], copyDuplicates: false), 0);
      expect(await notifier.importCombos([combo], copyDuplicates: true), 1);
      final combos = await container.read(comboListProvider.future);
      expect(combos.map((combo) => combo.id).toSet().length, combos.length);
      container.read(selectedComboIdProvider.notifier).selectCombo(combo.id);
      await notifier.deleteCombo(combo.id);
      expect(container.read(selectedComboIdProvider), isNull);
      expect((await ComboRepository(StorageService()).load()).length, 5);
    },
  );
}

class MemoryFiles extends FileService {
  final audio = <String, Uint8List>{
    'media:0f0f.wav': Uint8List.fromList(List.filled(44 + 22050 * 2, 7)),
  };
  @override
  Future<Uint8List> readAudio(String path) async => audio[path]!;
  @override
  Future<String> storeAudio(Uint8List bytes, String extension) async {
    final path = 'media:dl-${audio.length}.$extension';
    audio[path] = bytes;
    return path;
  }

  @override
  Future<bool> hasAudio(String path) async => audio.containsKey(path);
  @override
  Future<void> deleteAudio(String path) async => audio.remove(path);
}

void voiceSyncTests() {
  test(
    'Syncing from the server keeps the voice recorded on this device',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'token',
      });
      final storage = StorageService();
      final id = ComboRepository.ensureGuid('voice-combo');
      final local = ComboModel(
        id: id,
        name: 'Mẹ gọi',
        scenarioId: 'mother',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
        voicePath: 'media:0f0f.wav',
      );
      await ComboRepository(storage).save([local]);
      final server = MockClient(
        (request) async => http.Response(
          jsonEncode([
            {...ComboRepository.toServerMap(local), 'name': 'Tên trên server'},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final repository = ComboRepository(
        storage,
        api: ApiClient(
          storage: storage,
          httpClient: server,
          baseUrl: 'http://x',
        ),
      );
      final combos = await repository.load();
      expect(combos.single.name, 'Tên trên server');
      expect(combos.single.voicePath, 'media:0f0f.wav');
      // Lần tải sau (ví dụ mở lại app) vẫn còn giọng.
      expect((await repository.load()).single.voicePath, 'media:0f0f.wav');
    },
  );

  test(
    'Saving uploads the voice; deleting it tells the server to clear',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'token',
      });
      final storage = StorageService();
      final sent = <Map<String, dynamic>>[];
      var uploads = 0;
      final server = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/media/check')) {
          return http.Response(
            '{"existing":[]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/media')) {
          uploads++;
          return http.Response(
            '{"mediaId":"aaaaaaaa-0000-0000-0000-000000000001"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final files = MemoryFiles();
      final repository = ComboRepository(
        storage,
        api: ApiClient(
          storage: storage,
          httpClient: server,
          baseUrl: 'http://x',
        ),
        files: files,
      );
      final combo = ComboModel(
        id: ComboRepository.ensureGuid('c'),
        name: 'Mẹ',
        scenarioId: 'mother',
        callInterface: CallInterface.phone,
        createdAt: DateTime(2026),
        voicePath: 'media:0f0f.wav',
      );
      await repository.upsertRemote(combo);
      expect(uploads, 1);
      expect(sent.last['voiceMediaId'], 'aaaaaaaa-0000-0000-0000-000000000001');
      await repository.upsertRemote(combo.copyWith(stripCustomAudio: true));
      expect(sent.last['voiceMediaId'], ComboRepository.clearVoiceId);
    },
  );

  test(
    'Signing in on a new device downloads the voice from the server',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.accessTokenKey: 'token',
      });
      final storage = StorageService();
      final id = ComboRepository.ensureGuid('c');
      final wav = Uint8List.fromList(List.filled(44 + 22050 * 2, 1));
      final server = MockClient((request) async {
        if (request.url.path.endsWith(
          '/media/aaaaaaaa-0000-0000-0000-000000000001',
        )) {
          return http.Response.bytes(wav, 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': id,
              'name': 'Mẹ',
              'scenarioId': 'mother',
              'callInterface': 'phone',
              'ringtoneType': 'interfaceDefault',
              'backgroundSoundIds': <String>[],
              'voiceMediaId': 'aaaaaaaa-0000-0000-0000-000000000001',
              'createdAt': '2026-01-01T00:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final files = MemoryFiles();
      final repository = ComboRepository(
        storage,
        api: ApiClient(
          storage: storage,
          httpClient: server,
          baseUrl: 'http://x',
        ),
        files: files,
      );
      final combo = (await repository.load()).single;
      expect(combo.voicePath, isNotNull);
      expect(files.audio[combo.voicePath], wav);
      // Lần tải sau dùng bản trên máy, không tải lại.
      final before = files.audio.length;
      expect((await repository.load()).single.voicePath, combo.voicePath);
      expect(files.audio.length, before);
    },
  );

  test('A take shorter than half a second counts as empty', () {
    expect(VoiceRecorder.hasAudio(Uint8List(44)), isFalse);
    expect(VoiceRecorder.hasAudio(Uint8List(44 + 22050 * 2 ~/ 4)), isFalse);
    expect(VoiceRecorder.hasAudio(Uint8List(44 + 22050 * 2)), isTrue);
  });
}
