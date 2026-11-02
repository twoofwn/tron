import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

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

String _mimeType(String name) => name.endsWith('.mp3')
    ? 'audio/mpeg'
    : name.endsWith('.mp4')
    ? 'video/mp4'
    : 'audio/wav';

Future<String> mediaFileUri(String name) async => Uri.dataFromBytes(
  await readMediaFile(name),
  mimeType: _mimeType(name),
).toString();

/// Trên web không có file thật: tạo blob URL một lần (nhẹ hơn nhiều so với data
/// URI cho video vài chục MB); [FileService] nhớ và dùng lại URL này.
Future<String> mediaFileLocation(String name) async {
  final bytes = await readMediaFile(name);
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: _mimeType(name)),
  );
  return web.URL.createObjectURL(blob);
}

/// Giải phóng blob URL khi file bị xoá.
void releaseMediaLocation(String location) {
  if (location.startsWith('blob:')) {
    web.URL.revokeObjectURL(location);
  }
}

/// Trên web, thư viện thu âm tự giữ bản thu và trả về blob URL.
Future<String> tempRecordingPath(String name) async => '';

/// Blob URL do trình duyệt quản lý, không có file tạm để xoá.
Future<void> deleteTempFile(String path) async {}

Future<bool> mediaFileExists(String name) async =>
    (await SharedPreferences.getInstance()).containsKey('tron.audio.$name');

Future<void> deleteMediaFile(String name) async =>
    (await SharedPreferences.getInstance()).remove('tron.audio.$name');

/// Số byte thật của file (chuỗi base64 dài hơn khoảng 4/3).
Future<int> mediaFileSize(String name) async {
  final value = (await SharedPreferences.getInstance()).getString(
    'tron.audio.$name',
  );
  return value == null ? 0 : value.length * 3 ~/ 4;
}
