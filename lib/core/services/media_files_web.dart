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
  mimeType: name.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav',
).toString();
