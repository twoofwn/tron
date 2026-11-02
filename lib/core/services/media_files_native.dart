import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<void> writeMediaFile(String name, Uint8List bytes) async {
  final directory = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/tron_audio',
  );
  await directory.create(recursive: true);
  await File('${directory.path}/$name').writeAsBytes(bytes, flush: true);
}

Future<Uint8List> readMediaFile(String name) async =>
    File('${(await getApplicationDocumentsDirectory()).path}/tron_audio/$name')
        .readAsBytes();

/// Đường dẫn tuyệt đối của file (trình phát video cần file thật).
Future<String> mediaFileLocation(String name) async =>
    '${(await getApplicationDocumentsDirectory()).path}/tron_audio/$name';

Future<String> mediaFileUri(String name) async => Uri.file(
  '${(await getApplicationDocumentsDirectory()).path}/tron_audio/$name',
).toString();

/// Đường dẫn tạm cho một bản thu mới.
Future<String> tempRecordingPath(String name) async =>
    '${(await getTemporaryDirectory()).path}/$name';

/// Xoá file tạm sau khi đã chép bản thu vào thư mục âm thanh của app.
Future<void> deleteTempFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // File đã bị xoá hoặc không tồn tại: không cần làm gì.
  }
}

Future<bool> mediaFileExists(String name) async =>
    File('${(await getApplicationDocumentsDirectory()).path}/tron_audio/$name')
        .exists();

Future<void> deleteMediaFile(String name) async => deleteTempFile(
  '${(await getApplicationDocumentsDirectory()).path}/tron_audio/$name',
);
