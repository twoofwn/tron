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
Future<String> mediaFileUri(String name) async => Uri.file(
  '${(await getApplicationDocumentsDirectory()).path}/tron_audio/$name',
).toString();
