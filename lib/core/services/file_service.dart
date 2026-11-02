import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import 'media_files.dart' as media;

final fileServiceProvider = Provider((ref) => FileService());

class FileService {
  /// Báo lỗi dễ hiểu khi file trống hoặc vượt giới hạn, kèm dung lượng thật.
  /// `what` là tên loại file trong câu báo, ví dụ "File MP3".
  static void ensureSize(
    int bytes, {
    required int limit,
    required String what,
  }) {
    if (bytes <= 0) {
      throw FormatException('$what trống. Hãy chọn file khác.');
    }
    if (bytes > limit) {
      throw FormatException(
        '$what nặng ${sizeLabel(bytes)}, vượt giới hạn ${sizeLabel(limit)}. '
        'Hãy chọn file nhỏ hơn.',
      );
    }
  }

  /// Kiểm tra dung lượng trước khi đọc (không nạp file quá lớn vào bộ nhớ),
  /// rồi kiểm tra lại số byte thật đã đọc.
  static Future<Uint8List> _readWithin(
    PlatformFile file, {
    required int limit,
    required String what,
  }) async {
    final length = await file.length();
    if (length != null) {
      ensureSize(length, limit: limit, what: what);
    }
    final bytes = await file.readAsBytes();
    ensureSize(bytes.length, limit: limit, what: what);
    return bytes;
  }

  Future<String?> pickAudio() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (file == null) {
      return null;
    }
    final bytes = await _readWithin(
      file,
      limit: AppConstants.maxAudioBytes,
      what: 'File MP3',
    );
    return storeAudio(bytes, 'mp3');
  }

  /// Chọn video MP4 có sẵn trên máy làm video người gọi.
  Future<String?> pickVideo() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );
    if (file == null) {
      return null;
    }
    final bytes = await _readWithin(
      file,
      limit: AppConstants.maxVideoBytes,
      what: 'Video',
    );
    if (!isMp4(bytes)) {
      throw const FormatException(
        'File này không phải video MP4 hợp lệ. Hãy chọn file MP4 khác.',
      );
    }
    return storeVideo(bytes);
  }

  /// Lưu video MP4 vào thư mục media của app, trả về `media:UUID.mp4`.
  Future<String> storeVideo(Uint8List bytes) async {
    if (!isMp4(bytes) || bytes.length > AppConstants.maxVideoBytes) {
      throw const FormatException('File video không hợp lệ.');
    }
    final name = '${const Uuid().v4()}.mp4';
    await media.writeMediaFile(name, bytes);
    return 'media:$name';
  }

  /// MP4 bắt đầu bằng 4 byte độ dài rồi tới "ftyp" (giống cách server kiểm tra).
  static bool isMp4(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;

  /// Lưu file theo đuôi trong đường dẫn: video MP4 hoặc âm thanh.
  Future<String> storeMedia(Uint8List bytes, String extension) =>
      extension == 'mp4' ? storeVideo(bytes) : storeAudio(bytes, extension);

  Future<String> storeAudio(Uint8List bytes, String extension) async {
    if (!['mp3', 'wav'].contains(extension) ||
        bytes.isEmpty ||
        bytes.length > AppConstants.maxAudioBytes) {
      throw const FormatException('File âm thanh không hợp lệ.');
    }
    final name = '${const Uuid().v4()}.$extension';
    await media.writeMediaFile(name, bytes);
    return 'media:$name';
  }

  /// Đường dẫn file riêng của app: âm thanh (`.mp3`, `.wav`) hoặc video (`.mp4`).
  static final mediaPathPattern = RegExp(r'^media:[a-f0-9-]+\.(mp3|wav|mp4)$');

  /// Đường dẫn trỏ tới video người gọi.
  static bool isVideoPath(String path) => path.endsWith('.mp4');

  String _name(String path) {
    if (!mediaPathPattern.hasMatch(path)) {
      throw const FormatException('Đường dẫn âm thanh không hợp lệ.');
    }
    return path.substring(6);
  }

  Future<Uint8List> readAudio(String path) => readMedia(path);

  /// Đọc nội dung file riêng (âm thanh hoặc video).
  Future<Uint8List> readMedia(String path) => media.readMediaFile(_name(path));
  Future<String> audioUri(String path) => media.mediaFileUri(_name(path));

  /// Vị trí phát đã tìm cho từng video (`media:...mp4`), dùng lại cho các lần
  /// xem lại, đo độ dài và gọi video sau, khỏi phải nạp lại file mỗi lần.
  final _videoLocations = <String, Future<String>>{};

  /// Vị trí video cho trình phát: đường dẫn file trên máy, hoặc blob URL trên
  /// web. Chỉ tìm một lần cho mỗi file; lỗi thì lần sau tìm lại.
  Future<String> videoLocation(String path) {
    final cached = _videoLocations[path];
    if (cached != null) {
      return cached;
    }
    final Future<String> location;
    try {
      location = media.mediaFileLocation(_name(path));
    } on FormatException catch (error) {
      return Future.error(error);
    }
    _videoLocations[path] = location;
    location.catchError((Object _) {
      _videoLocations.remove(path);
      return '';
    });
    return location;
  }

  /// Bỏ vị trí đã nhớ của file (khi file bị xoá), giải phóng blob URL trên web.
  void _forgetLocation(String path) {
    final location = _videoLocations.remove(path);
    location?.then(media.releaseMediaLocation, onError: (Object _) {});
  }

  /// Dung lượng file riêng trên máy (byte); lỗi hoặc không có file thì 0.
  Future<int> mediaSize(String path) async {
    try {
      return await media.mediaFileSize(_name(path));
    } catch (_) {
      return 0;
    }
  }

  /// File âm thanh riêng còn trên máy không.
  Future<bool> hasAudio(String path) async {
    try {
      return await media.mediaFileExists(_name(path));
    } on FormatException {
      return false;
    }
  }

  /// Xoá file âm thanh riêng không còn combo nào dùng.
  Future<void> deleteAudio(String path) async {
    _forgetLocation(path);
    try {
      await media.deleteMediaFile(_name(path));
    } on FormatException {
      // Không phải file của app: bỏ qua.
    }
  }

  Future<Uint8List?> pickPackage() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ehc'],
    );
    if (file == null) {
      return null;
    }
    return _readWithin(
      file,
      limit: AppConstants.maxPackageBytes,
      what: 'File .ehc',
    );
  }

  Future<bool> savePackage(Uint8List bytes) async =>
      await FilePicker.saveFile(
        dialogTitle: 'Lưu combo TRỐN',
        fileName: 'tron_combos.ehc',
        mimeType: 'application/octet-stream',
        bytes: bytes,
      ) !=
      null;
}
