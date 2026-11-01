import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/sharing/repositories/sharing_repository.dart';
import 'package:tron/shared/enums/call_interface.dart';

class MemoryFileService extends FileService {
  final audio = <String, Uint8List>{
    'media:abcd.mp3': Uint8List.fromList([73, 68, 51, 1, 2]),
    'media:beef.wav': Uint8List.fromList([82, 73, 70, 70, 9]),
  };
  @override
  Future<Uint8List> readAudio(String path) async => audio[path]!;
  @override
  Future<String> storeAudio(Uint8List bytes, String extension) async {
    final path = 'media:copied-${audio.length}.$extension';
    audio[path] = bytes;
    return path;
  }
}

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
