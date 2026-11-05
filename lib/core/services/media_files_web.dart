import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

/// File âm thanh/video trên web lưu trong IndexedDB (giới hạn theo dung lượng
/// ổ đĩa), không lưu base64 trong localStorage: localStorage chỉ có khoảng 5 MB
/// cho cả app, một video vài MB là đầy và mọi lần lưu combo sau đó đều lỗi.
const _dbName = 'tron_media';
const _storeName = 'files';

/// Khoá cũ trong localStorage (bản app trước); đọc được thì chuyển sang IndexedDB.
String _legacyKey(String name) => 'tron.audio.$name';

Future<web.IDBDatabase>? _database;

Future<web.IDBDatabase> _open() => _database ??= () {
  final completer = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(_dbName, 1);
  request.onupgradeneeded = (web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore(_storeName);
  }.toJS;
  request.onsuccess = (web.Event _) {
    completer.complete(request.result as web.IDBDatabase);
  }.toJS;
  request.onerror = (web.Event _) {
    _database = null;
    completer.completeError(
      StateError('Không mở được bộ nhớ âm thanh: ${request.error?.message}'),
    );
  }.toJS;
  return completer.future;
}();

/// Chạy một thao tác trên kho file; ghi/xoá chỉ xong khi giao dịch hoàn tất.
Future<JSAny?> _run(
  String mode,
  web.IDBRequest Function(web.IDBObjectStore store) action,
) async {
  final transaction = (await _open()).transaction(_storeName.toJS, mode);
  final request = action(transaction.objectStore(_storeName));
  final completer = Completer<JSAny?>();
  transaction.oncomplete = (web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(request.result);
    }
  }.toJS;
  void fail(web.Event _) {
    if (!completer.isCompleted) {
      final error = transaction.error ?? request.error;
      completer.completeError(
        StateError(
          error?.name == 'QuotaExceededError'
              ? 'Không đủ bộ nhớ trình duyệt để lưu âm thanh/video.'
              : 'Không lưu được âm thanh: ${error?.message}',
        ),
      );
    }
  }

  transaction.onerror = fail.toJS;
  transaction.onabort = fail.toJS;
  return completer.future;
}

Future<Uint8List?> _get(String name) async {
  final value = await _run('readonly', (store) => store.get(name.toJS));
  return value == null ? null : (value as JSUint8Array).toDart;
}

/// Đọc file từ khoá cũ trong localStorage, chuyển sang IndexedDB rồi xoá khoá
/// cũ để trả lại chỗ cho dữ liệu combo.
Future<Uint8List?> _migrateLegacy(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_legacyKey(name));
  if (value == null) {
    return null;
  }
  final bytes = base64Decode(value);
  await writeMediaFile(name, bytes);
  await prefs.remove(_legacyKey(name));
  return bytes;
}

/// Chuyển mọi file kiểu cũ từ localStorage sang IndexedDB ngay, không đợi tới
/// lúc đọc: còn nằm trong localStorage thì nó chiếm gần hết ~5 MB và mọi lần
/// lưu danh sách combo đều lỗi. Gọi khi mở app và khi lưu dữ liệu bị lỗi.
Future<void> releaseLegacyMediaStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final legacy = prefs
      .getKeys()
      .where((key) => key.startsWith(_legacyKey('')))
      .toList();
  for (final key in legacy) {
    await _migrateLegacy(key.substring(_legacyKey('').length));
  }
}

Future<void> writeMediaFile(String name, Uint8List bytes) async {
  await _run('readwrite', (store) => store.put(bytes.toJS, name.toJS));
}

Future<Uint8List> readMediaFile(String name) async {
  final bytes = await _get(name) ?? await _migrateLegacy(name);
  if (bytes == null) {
    throw StateError('Không tìm thấy âm thanh.');
  }
  return bytes;
}

String _mimeType(String name) => name.endsWith('.mp3')
    ? 'audio/mpeg'
    : name.endsWith('.mp4')
    ? 'video/mp4'
    : name.endsWith('.jpg')
    ? 'image/jpeg'
    : name.endsWith('.png')
    ? 'image/png'
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

Future<bool> mediaFileExists(String name) async {
  final count = await _run('readonly', (store) => store.count(name.toJS));
  return (count as JSNumber).toDartInt > 0 ||
      (await SharedPreferences.getInstance()).containsKey(_legacyKey(name));
}

Future<void> deleteMediaFile(String name) async {
  await _run('readwrite', (store) => store.delete(name.toJS));
  await (await SharedPreferences.getInstance()).remove(_legacyKey(name));
}

Future<int> mediaFileSize(String name) async =>
    (await _get(name))?.length ?? (await _migrateLegacy(name))?.length ?? 0;
