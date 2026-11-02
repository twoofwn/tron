import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> writeMediaFile(String name, Uint8List bytes) async {
  if (!await (await SharedPreferences.getInstance()).setString(
    'tron.audio.$name',
    base64Encode(bytes),
  )) {
    throw StateError('Không đủ bộ nhớ lưu âm thanh.');
  }
}

Future<Uint8List> readMediaFile(String name) async {
  final value = (await SharedPreferences.getInstance()).getString(
    'tron.audio.$name',
  );
  if (value == null) {
    throw StateError('Không tìm thấy âm thanh.');
  }
  return base64Decode(value);
}

Future<String> mediaFileUri(String name) async => Uri.dataFromBytes(
  await readMediaFile(name),
  mimeType: name.endsWith('.mp3')
      ? 'audio/mpeg'
      : name.endsWith('.mp4')
      ? 'video/mp4'
      : 'audio/wav',
).toString();

/// Trên web không có file thật: trình phát video đọc data URI.
Future<String> mediaFileLocation(String name) => mediaFileUri(name);

/// Trên web, thư viện thu âm tự giữ bản thu và trả về blob URL.
Future<String> tempRecordingPath(String name) async => '';

/// Blob URL do trình duyệt quản lý, không có file tạm để xoá.
Future<void> deleteTempFile(String path) async {}

Future<bool> mediaFileExists(String name) async =>
    (await SharedPreferences.getInstance()).containsKey('tron.audio.$name');

Future<void> deleteMediaFile(String name) async =>
    (await SharedPreferences.getInstance()).remove('tron.audio.$name');
