import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/sharing/repositories/sharing_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

class MemoryFileService extends FileService {
  final audio = <String, Uint8List>{
    'media:abcd.mp3': Uint8List.fromList([73, 68, 51, 1, 2]),
    'media:beef.wav': Uint8List.fromList([82, 73, 70, 70, 9]),
    'media:cafe.mp4': Uint8List.fromList([
      0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 1, 2, 3, 4, //
    ]),
  };
  @override
  Future<Uint8List> readMedia(String path) async => audio[path]!;
  @override
  Future<String> storeAudio(Uint8List bytes, String extension) async {
    final path = 'media:copied-${audio.length}.$extension';
    audio[path] = bytes;
    return path;
  }

  @override
  Future<String> storeVideo(Uint8List bytes) async {
    final path = 'media:copied-${audio.length}.mp4';
    audio[path] = bytes;
    return path;
  }

  @override
  Future<String> storeImage(Uint8List bytes) async {
    final path =
        'media:copied-${audio.length}.${FileService.imageExtension(bytes)}';
    audio[path] = bytes;
    return path;
  }
}

/// Ảnh JPG giả (đủ dài để nhận ra loại ảnh).
final _jpg = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  ...List.filled(20, 7),
]);

void main() {
  late SharingRepository repository;
  late MemoryFileService files;
  final combo = ComboModel(
    id: 'test-combo',
    name: 'Mẹ gọi về nhà',
    scenarioId: 'mother',
    callInterface: CallInterface.phone,
    createdAt: DateTime(2026),
    ringtoneType: RingtoneType.custom,
    ringtonePath: 'media:abcd.mp3',
    backgroundSoundPaths: const ['rain'],
  );
  const friendScenario = Scenario(
    id: 'user-friend-scenario-1',
    title: 'Bạn thân rủ đi ăn lẩu',
    category: ScenarioCategory.personal,
    source: ScenarioSource.user,
    callerName: 'Minh Bạn Thân',
    initial: 'M',
    defaultBackgroundId: 'cafe',
    steps: [
      DialogueStep(
        id: 'step-1',
        type: DialogueStepType.speech,
        text: 'Alo ra quán lẩu đầu ngõ ngay nhé!',
        audioPath: '/data/user/0/foreign/local_recording.m4a',
        seconds: 4,
      ),
      DialogueStep(
        id: 'step-2',
        type: DialogueStepType.wait,
        text: '(Chờ bạn trả lời)',
        seconds: 0,
      ),
    ],
  );
  setUp(() {
    files = MemoryFileService();
    repository = SharingRepository(files);
  });
  test('Code can be decoded on another device without a server', () async {
    final package = await repository.create([combo], includeAudio: false);
    final imported = SharingRepository(MemoryFileService())
        .decodeCode(repository.code(package));
    expect(imported.combos.single.name, combo.name);
    expect(imported.combos.single.ringtoneType, RingtoneType.interfaceDefault);
    expect(imported.combos.single.ringtonePath, isNull);
    expect(imported.audio, isEmpty);
  });
  test('Friend custom scenario can be shared standalone or with combo via code and QR', () async {
    final standalonePkg = await repository.create(
      const [],
      scenarios: const [friendScenario],
      includeAudio: false,
    );
    final standaloneDecoded = SharingRepository(MemoryFileService())
        .decodeCode(repository.code(standalonePkg));
    expect(standaloneDecoded.combos, isEmpty);
    expect(standaloneDecoded.scenarios.single.id, friendScenario.id);
    expect(standaloneDecoded.scenarios.single.title, friendScenario.title);
    expect(standaloneDecoded.scenarios.single.steps.first.audioPath, isNull);

    final customCombo = ComboModel(
      id: 'friend-combo',
      name: 'Bạn thân rủ đi ăn lẩu',
      scenarioId: friendScenario.id,
      callInterface: CallInterface.phone,
      createdAt: DateTime(2026),
    );
    final comboWithScenarioPkg = await repository.create(
      [customCombo],
      scenarios: const [friendScenario],
      includeAudio: false,
    );
    final comboDecoded = SharingRepository(MemoryFileService())
        .decodeCode(repository.code(comboWithScenarioPkg));
    expect(comboDecoded.combos.single.scenarioId, friendScenario.id);
    expect(comboDecoded.scenarios.single.id, friendScenario.id);
  });
  test('Caller photo travels with the package even without audio', () async {
    files.audio['media:face.jpg'] = _jpg;
    final withPhoto = combo.copyWith(
      id: 'photo-combo',
      avatarPath: 'media:face.jpg',
      avatarMediaId: 'server-id',
    );
    final package = await repository.create([withPhoto], includeAudio: false);
    expect(package.audio.keys, ['media:face.jpg']);
    final receiver = MemoryFileService();
    final other = SharingRepository(receiver);
    final decoded = other.decodeCode(repository.code(package));
    final imported = (await other.materialize(decoded, {withPhoto.id})).single;
    // Âm thanh riêng bị bỏ, ảnh vẫn còn và được lưu thành file mới trên máy nhận.
    expect(imported.ringtonePath, isNull);
    expect(imported.avatarPath, isNot('media:face.jpg'));
    expect(imported.avatarPath, endsWith('.jpg'));
    expect(receiver.audio[imported.avatarPath], _jpg);
    expect(imported.avatarMediaId, isNull);
  });
  test('A package whose photo is not an image is rejected', () async {
    files.audio['media:face.jpg'] = Uint8List.fromList(List.filled(24, 1));
    final package = await repository.create([
      combo.copyWith(id: 'bad-photo', avatarPath: 'media:face.jpg'),
    ], includeAudio: false);
    expect(
      () => repository.decode(repository.encode(package)),
      throwsFormatException,
    );
  });
  test(
    'Audio file package restores bytes and rewrites local references',
    () async {
      final package = await repository.create([combo], includeAudio: true);
      final decoded = repository.decode(repository.encode(package));
      final imported = await repository.materialize(decoded, {combo.id});
      expect(imported.single.ringtonePath, isNot(combo.ringtonePath));
      expect(
        files.audio[imported.single.ringtonePath],
        files.audio[combo.ringtonePath],
      );
      expect(await repository.materialize(decoded, {}), isEmpty);
    },
  );
  test('Recorded caller voice travels with the package', () async {
    final withVoice = combo.copyWith(
      id: 'voice-combo',
      voicePath: 'media:beef.wav',
    );
    final package = await repository.create([withVoice], includeAudio: true);
    final decoded = repository.decode(repository.encode(package));
    final imported = await repository.materialize(decoded, {withVoice.id});
    expect(imported.single.voicePath, isNot(withVoice.voicePath));
    expect(
      files.audio[imported.single.voicePath],
      files.audio['media:beef.wav'],
    );
  });
  test('Recorded caller video travels with the package', () async {
    final withVideo = combo.copyWith(
      id: 'video-combo',
      callType: CallType.video,
      videoPath: 'media:cafe.mp4',
    );
    final package = await repository.create([withVideo], includeAudio: true);
    final decoded = repository.decode(repository.encode(package));
    final imported = await repository.materialize(decoded, {withVideo.id});
    expect(imported.single.callType, CallType.video);
    expect(imported.single.videoPath, endsWith('.mp4'));
    expect(imported.single.videoPath, isNot(withVideo.videoPath));
    expect(
      files.audio[imported.single.videoPath],
      files.audio['media:cafe.mp4'],
    );
  });
  test('Without attached media a video call keeps its type only', () async {
    final withVideo = combo.copyWith(
      callType: CallType.video,
      videoPath: 'media:cafe.mp4',
    );
    final package = await repository.create([withVideo], includeAudio: false);
    expect(package.combos.single.callType, CallType.video);
    expect(package.combos.single.videoPath, isNull);
    expect(package.audio, isEmpty);
  });
  test('Rejects a package whose video is not an MP4', () async {
    final withVideo = combo.copyWith(videoPath: 'media:cafe.mp4');
    final json = jsonDecode(
      utf8.decode(
        repository.encode(
          await repository.create([withVideo], includeAudio: true),
        ),
      ),
    ) as Map<String, Object?>;
    final audio = Map<String, Object?>.from(json['audio'] as Map)
      ..['media:cafe.mp4'] = base64Encode(List.filled(12, 1));
    expect(
      () => repository.decode(
        Uint8List.fromList(utf8.encode(jsonEncode({...json, 'audio': audio}))),
      ),
      throwsFormatException,
    );
  });
  test(
    'Without attached audio the voice falls back to the scenario reader',
    () async {
      final withVoice = combo.copyWith(voicePath: 'media:beef.wav');
      final package = await repository.create([withVoice], includeAudio: false);
      expect(package.combos.single.voicePath, isNull);
      expect(package.audio, isEmpty);
    },
  );
  test('Rejects a package whose voice recording is missing', () async {
    final withVoice = combo.copyWith(voicePath: 'media:beef.wav');
    final json = jsonDecode(
      utf8.decode(
        repository.encode(
          await repository.create([withVoice], includeAudio: true),
        ),
      ),
    ) as Map<String, Object?>;
    final audio = Map<String, Object?>.from(json['audio'] as Map)
      ..remove('media:beef.wav');
    expect(
      () => repository.decode(
        Uint8List.fromList(utf8.encode(jsonEncode({...json, 'audio': audio}))),
      ),
      throwsFormatException,
    );
  });
  test('Rejects invalid format, foreign paths, missing audio and unknown scenarios', () async {
    expect(() => repository.decodeCode('EH-7K2Q'), throwsFormatException);
    final valid = jsonDecode(
      utf8.decode(
        repository.encode(await repository.create([combo], includeAudio: true)),
      ),
    ) as Map<String, Object?>;
    for (final invalid in [
      {...valid, 'version': 99},
      {...valid, 'audio': <String, String>{}},
      {
        ...valid,
        'audio': {'../../external.mp3': 'AQI='},
      },
      {
        ...valid,
        'combos': [
          {...combo.toJson(), 'scenarioId': 'unknown'},
        ],
      },
    ]) {
      expect(
        () => repository.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(invalid))),
        ),
        throwsFormatException,
      );
    }
  });
}
