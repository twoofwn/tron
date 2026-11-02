import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import 'media_files.dart' as media;

final fileServiceProvider = Provider((ref) => FileService());

class FileService {
  Future<String?> pickAudio() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (file == null) {
      return null;
    }
    final length = await file.length();
    if (length == null || length > AppConstants.maxAudioBytes) {
      throw const FormatException('Chọn file MP3 tối đa 10 MB.');
    }
    return storeAudio(await file.readAsBytes(), 'mp3');
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
    final length = await file.length();
    if (length == null || length > AppConstants.maxVideoBytes) {
      throw const FormatException('Chọn video MP4 tối đa 20 MB.');
    }
    return storeVideo(await file.readAsBytes());
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

  /// Vị trí video cho trình phát: đường dẫn file trên máy, hoặc data URI trên web.
  Future<String> videoLocation(String path) =>
      media.mediaFileLocation(_name(path));

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
    final length = await file.length();
    if (length == null || length > AppConstants.maxPackageBytes) {
      throw const FormatException('File .ehc tối đa 25 MB.');
    }
    return file.readAsBytes();
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
