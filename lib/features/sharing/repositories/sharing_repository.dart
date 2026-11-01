import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/file_service.dart';
import '../../combo/models/combo_model.dart';
import '../../scenarios/data/scenario_lookup.dart';
import '../models/combo_package.dart';

final sharingRepositoryProvider = Provider(
  (ref) => SharingRepository(ref.watch(fileServiceProvider)),
);

class SharingRepository {
  SharingRepository(this.files, {String Function()? createId})
    : _createId = createId ?? (() => const Uuid().v4());
  final FileService files;
  final String Function() _createId;
  Future<ComboPackage> create(
    List<ComboModel> combos, {
    required bool includeAudio,
  }) async {
    if (combos.isEmpty) {
      throw const FormatException('Chọn ít nhất một combo để xuất.');
    }
    if (combos.length > 100) {
      throw const FormatException('Mỗi gói có tối đa 100 combo.');
    }
    final audio = <String, Uint8List>{};
    if (includeAudio) {
      for (final combo in combos) {
        for (final path in combo.customAudioPaths) {
          audio[path] = await files.readAudio(path);
        }
      }
    }
    final package = ComboPackage(
      id: _createId(),
      combos: combos
          .map(
            (combo) => includeAudio
                ? combo.withoutSync()
                : combo.copyWith(stripCustomAudio: true),
          )
          .toList(),
      audio: audio,
    );
    if (encode(package).length > AppConstants.maxPackageBytes) {
      throw const FormatException(
        'Gói vượt 25 MB. Hãy chọn ít combo hoặc bỏ âm thanh.',
      );
    }
    return package;
  }

  Uint8List encode(ComboPackage package) => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'tron.ehc',
        'version': 1,
        'id': package.id,
        'combos': package.combos.map((combo) => combo.toJson()).toList(),
        'audio': package.audio.map(
          (key, bytes) => MapEntry(key, base64Encode(bytes)),
        ),
      }),
    ),
  );
  String code(ComboPackage package) =>
      'TRON1.${base64UrlEncode(encode(package))}';
  ComboPackage decodeCode(String code) {
    final value = code.trim();
    if (!value.startsWith('TRON1.') ||
        value.length > AppConstants.maxPackageBytes * 2) {
      throw const FormatException('Mã chia sẻ TRỐN không hợp lệ.');
    }
    try {
      return decode(base64Url.decode(value.substring(6)));
    } catch (_) {
      throw const FormatException('Mã chia sẻ bị lỗi hoặc không được hỗ trợ.');
    }
  }

  ComboPackage decode(Uint8List bytes) {
    try {
      if (bytes.length > AppConstants.maxPackageBytes) {
        throw const FormatException();
      }
      final json = Map<String, Object?>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      if (json['format'] != 'tron.ehc' || json['version'] != 1) {
        throw const FormatException();
      }
      final records = json['combos'] as List;
      if (records.isEmpty || records.length > 100) {
        throw const FormatException();
      }
      final combos = records
          .map(
            (item) =>
                ComboModel.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
      if (combos.map((combo) => combo.id).toSet().length != combos.length) {
        throw const FormatException();
      }
      final encodedAudio = Map<String, Object?>.from(json['audio'] as Map);
      final audio = <String, Uint8List>{};
      for (final entry in encodedAudio.entries) {
        if (!RegExp(r'^media:[a-f0-9-]+\.(mp3|wav)$').hasMatch(entry.key)) {
          throw const FormatException();
        }
        final data = base64Decode(entry.value as String);
        if (data.isEmpty || data.length > AppConstants.maxAudioBytes) {
          throw const FormatException();
        }
        audio[entry.key] = data;
      }
      for (final combo in combos) {
        if (!ScenarioLookup.isShareableId(combo.scenarioId)) {
          throw const FormatException();
        }
        for (final path in combo.customAudioPaths) {
          if (!audio.containsKey(path)) {
            throw const FormatException();
          }
        }
      }
      return ComboPackage(
        id: json['id'] as String,
        combos: combos,
        audio: audio,
      );
    } catch (_) {
      throw const FormatException(
        'File không phải gói TRỐN hợp lệ, bị hỏng hoặc vượt giới hạn.',
      );
    }
  }

  Future<List<ComboModel>> materialize(
    ComboPackage package,
    Set<String> selectedIds,
  ) async {
    final selected = package.combos
        .where((combo) => selectedIds.contains(combo.id))
        .toList();
    final paths = <String, String>{};
    for (final combo in selected) {
      for (final path in combo.customAudioPaths) {
        if (!paths.containsKey(path)) {
          paths[path] = await files.storeAudio(
            package.audio[path]!,
            path.split('.').last,
          );
        }
      }
    }
    return selected
        .map(
          (combo) => combo
              .copyWith(
                ringtonePath: paths[combo.ringtonePath],
                customBackgroundPath: paths[combo.customBackgroundPath],
                voicePath: paths[combo.voicePath],
              )
              .withoutSync(),
        )
        .toList();
  }
}
