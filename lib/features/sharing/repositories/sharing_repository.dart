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
    // Ước tính trước khi đọc file: gói quá lớn bị từ chối ngay, không phải chờ
    // đọc và mã hoá hết âm thanh/video rồi mới báo.
    final estimate = await estimateSize(combos, includeAudio: includeAudio);
    if (estimate > AppConstants.maxPackageBytes) {
      throw FormatException(_tooLargeMessage(estimate));
    }
    final audio = <String, Uint8List>{};
    if (includeAudio) {
      for (final combo in combos) {
        for (final path in combo.customMediaPaths) {
          audio[path] = await files.readMedia(path);
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
    final size = encode(package).length;
    if (size > AppConstants.maxPackageBytes) {
      throw FormatException(_tooLargeMessage(size));
    }
    return package;
  }

  static String _tooLargeMessage(int bytes) =>
      'Gói nặng khoảng ${sizeLabel(bytes)}, vượt giới hạn '
      '${sizeLabel(AppConstants.maxPackageBytes)}. Hãy chọn ít combo hơn '
      'hoặc bỏ kèm âm thanh và video.';

  /// Dung lượng ước tính của gói (byte), chưa cần đọc file: phần combo nhỏ,
  /// file đính kèm nặng thêm khoảng 1/3 vì được mã hoá base64.
  Future<int> estimateSize(
    List<ComboModel> combos, {
    required bool includeAudio,
  }) async {
    var bytes = 512 + combos.length * 600;
    if (includeAudio) {
      final paths = {for (final combo in combos) ...combo.customMediaPaths};
      for (final path in paths) {
        bytes += (await files.mediaSize(path)) * 4 ~/ 3 + 64;
      }
    }
    return bytes;
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
    if (!value.startsWith('TRON1.')) {
      throw const FormatException('Mã chia sẻ TRỐN không hợp lệ.');
    }
    // Mã là gói mã hoá base64url: dài hơn gói gốc khoảng 1/3.
    if (value.length > AppConstants.maxPackageBytes * 4 ~/ 3 + 16) {
      throw FormatException(
        'Mã chia sẻ quá dài (gói khoảng ${sizeLabel(value.length * 3 ~/ 4)}, '
        'giới hạn ${sizeLabel(AppConstants.maxPackageBytes)}). '
        'Hãy nhập bằng file .ehc.',
      );
    }
    try {
      return decode(base64Url.decode(value.substring(6)));
    } catch (_) {
      throw const FormatException('Mã chia sẻ bị lỗi hoặc không được hỗ trợ.');
    }
  }

  ComboPackage decode(Uint8List bytes) {
    FileService.ensureSize(
      bytes.length,
      limit: AppConstants.maxPackageBytes,
      what: 'Gói chia sẻ',
    );
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
        if (!FileService.mediaPathPattern.hasMatch(entry.key)) {
          throw const FormatException();
        }
        final data = base64Decode(entry.value as String);
        final isVideo = FileService.isVideoPath(entry.key);
        final limit = isVideo
            ? AppConstants.maxVideoBytes
            : AppConstants.maxAudioBytes;
        if (data.isEmpty ||
            data.length > limit ||
            (isVideo && !FileService.isMp4(data))) {
          throw const FormatException();
        }
        audio[entry.key] = data;
      }
      for (final combo in combos) {
        // Gọi video không dùng kịch bản nên không cần kiểm tra ID kịch bản.
        if (!combo.isVideoCall &&
            !ScenarioLookup.isShareableId(combo.scenarioId)) {
          throw const FormatException();
        }
        for (final path in combo.customMediaPaths) {
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
      for (final path in combo.customMediaPaths) {
        if (!paths.containsKey(path)) {
          paths[path] = await files.storeMedia(
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
                videoPath: paths[combo.videoPath],
              )
              .withoutSync(),
        )
        .toList();
  }
}
