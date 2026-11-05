import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/file_service.dart';
import '../../combo/models/combo_model.dart';
import '../../scenarios/data/scenario_lookup.dart';
import '../../scenarios/data/scenario_repository.dart';
import '../../scenarios/models/scenario.dart';
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
    List<Scenario> scenarios = const [],
    required bool includeAudio,
  }) async {
    if (combos.isEmpty && scenarios.isEmpty) {
      throw const FormatException(
        'Chọn ít nhất một combo hoặc kịch bản để xuất.',
      );
    }
    if (combos.length > 100) {
      throw const FormatException('Mỗi gói có tối đa 100 combo.');
    }
    if (scenarios.length > 100) {
      throw const FormatException('Mỗi gói có tối đa 100 kịch bản.');
    }
    // Ước tính trước khi đọc file: gói quá lớn bị từ chối ngay, không phải chờ
    // đọc và mã hoá hết âm thanh/video rồi mới báo.
    final estimate = await estimateSize(
      combos,
      scenarios: scenarios,
      includeAudio: includeAudio,
    );
    if (estimate > AppConstants.maxPackageBytes) {
      throw FormatException(_tooLargeMessage(estimate));
    }
    final audio = <String, Uint8List>{};
    for (final combo in combos) {
      for (final path in _packedPaths(combo, includeAudio: includeAudio)) {
        audio[path] = await files.readMedia(path);
      }
    }
    final normalizedScenarios = scenarios
        .map((sc) => _sanitizeScenarioForShare(sc))
        .toList();
    final package = ComboPackage(
      id: _createId(),
      combos: combos
          .map(
            (combo) => includeAudio
                ? combo.withoutSync()
                : combo.copyWith(stripCustomAudio: true),
          )
          .toList(),
      scenarios: normalizedScenarios,
      audio: audio,
    );
    final size = encode(package).length;
    if (size > AppConstants.maxPackageBytes) {
      throw FormatException(_tooLargeMessage(size));
    }
    return package;
  }

  static Scenario _sanitizeScenarioForShare(Scenario sc) {
    final steps = sc.steps
        .map(
          (st) => DialogueStep(
            id: st.id,
            type: st.type,
            text: st.text,
            audioPath:
                st.audioPath != null &&
                    ScenarioRepository.isBundledAudio(st.audioPath!)
                ? st.audioPath
                : null,
            seconds: st.seconds,
          ),
        )
        .toList();
    return sc.copyWith(source: ScenarioSource.user, steps: steps);
  }

  /// File đi kèm combo trong gói. Ảnh đại diện nhẹ nên luôn đi theo combo;
  /// âm thanh và video chỉ đi kèm khi người dùng chọn.
  static List<String> _packedPaths(
    ComboModel combo, {
    required bool includeAudio,
  }) => includeAudio ? combo.customMediaPaths : [?combo.avatarPath];

  static String _tooLargeMessage(int bytes) =>
      'Gói nặng khoảng ${sizeLabel(bytes)}, vượt giới hạn '
      '${sizeLabel(AppConstants.maxPackageBytes)}. Hãy chọn ít combo hơn '
      'hoặc bỏ kèm âm thanh và video.';

  /// Dung lượng ước tính của gói (byte), chưa cần đọc file: phần combo nhỏ,
  /// file đính kèm nặng thêm khoảng 1/3 vì được mã hoá base64.
  Future<int> estimateSize(
    List<ComboModel> combos, {
    List<Scenario> scenarios = const [],
    required bool includeAudio,
  }) async {
    var bytes = 512 + combos.length * 600 + scenarios.length * 800;
    final paths = {
      for (final combo in combos)
        ..._packedPaths(combo, includeAudio: includeAudio),
    };
    for (final path in paths) {
      bytes += (await files.mediaSize(path)) * 4 ~/ 3 + 64;
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
        if (package.scenarios.isNotEmpty)
          'scenarios': package.scenarios.map((s) => s.toJson()).toList(),
        'audio': package.audio.map(
          (key, bytes) => MapEntry(key, base64Encode(bytes)),
        ),
      }),
    ),
  );

  String code(ComboPackage package) =>
      'TRON1.${base64UrlEncode(encode(package))}';

  /// Lấy mã `TRON1.…` nằm trong đoạn chữ được dán (ví dụ cả tin nhắn).
  /// Không dùng RegExp vì mã dài hàng chục MB làm RegExp tràn stack.
  static String _extractCode(String text) {
    final start = text.toUpperCase().indexOf('TRON1.');
    if (start < 0) return text;
    var end = start + 6;
    while (end < text.length && _isCodeChar(text.codeUnitAt(end))) {
      end++;
    }
    return text.substring(start, end);
  }

  static bool _isCodeChar(int c) =>
      (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      c == 0x5F || // _
      c == 0x2D || // -
      c == 0x2B || // +
      c == 0x2F || // /
      c == 0x3D; // =

  ComboPackage decodeCode(String code) {
    final value = _extractCode(code.trim());
    if (!value.toUpperCase().startsWith('TRON1.')) {
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
      final payload = base64Url.normalize(
        value.substring(6).replaceAll('+', '-').replaceAll('/', '_'),
      );
      return decode(base64Url.decode(payload));
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
      final records = (json['combos'] as List?) ?? const [];
      final rawScenarios =
          (json['scenarios'] ?? json['customScenarios']) as List? ?? const [];
      if ((records.isEmpty && rawScenarios.isEmpty) ||
          records.length > 100 ||
          rawScenarios.length > 100) {
        throw const FormatException();
      }
      final scenarios = rawScenarios
          .map(
            (item) => _sanitizeScenarioForShare(
              Scenario.fromJson(Map<String, dynamic>.from(item as Map)),
            ),
          )
          .toList();
      final scenarioIdsInPackage = scenarios.map((s) => s.id).toSet();

      final combos = records
          .map(
            (item) =>
                ComboModel.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList();
      if (combos.map((combo) => combo.id).toSet().length != combos.length) {
        throw const FormatException();
      }
      final rawAudio = json['audio'];
      final encodedAudio = rawAudio is Map
          ? Map<String, Object?>.from(rawAudio)
          : const <String, Object?>{};
      final audio = <String, Uint8List>{};
      for (final entry in encodedAudio.entries) {
        if (!FileService.mediaPathPattern.hasMatch(entry.key)) {
          throw const FormatException();
        }
        final data = base64Decode(entry.value as String);
        final isVideo = FileService.isVideoPath(entry.key);
        final isImage = FileService.isImagePath(entry.key);
        final limit = isVideo
            ? AppConstants.maxVideoBytes
            : isImage
            ? AppConstants.maxAvatarBytes
            : AppConstants.maxAudioBytes;
        if (data.isEmpty ||
            data.length > limit ||
            (isVideo && !FileService.isMp4(data)) ||
            (isImage && FileService.imageExtension(data) == null)) {
          throw const FormatException();
        }
        audio[entry.key] = data;
      }
      for (final combo in combos) {
        // Gọi video không dùng kịch bản nên không cần kiểm tra ID kịch bản.
        // Gói chia sẻ cho phép kịch bản có sẵn hoặc kịch bản tuỳ chỉnh đi kèm trong gói.
        if (!combo.isVideoCall &&
            !ScenarioLookup.isShareableId(combo.scenarioId) &&
            !scenarioIdsInPackage.contains(combo.scenarioId)) {
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
        scenarios: scenarios,
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
                avatarPath: paths[combo.avatarPath],
              )
              .withoutSync(),
        )
        .toList();
  }
}
