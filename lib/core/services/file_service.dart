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

  String _name(String path) {
    if (!RegExp(r'^media:[a-f0-9-]+\.(mp3|wav)$').hasMatch(path)) {
      throw const FormatException('Đường dẫn âm thanh không hợp lệ.');
    }
    return path.substring(6);
  }

  Future<Uint8List> readAudio(String path) => media.readMediaFile(_name(path));
  Future<String> audioUri(String path) => media.mediaFileUri(_name(path));

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
