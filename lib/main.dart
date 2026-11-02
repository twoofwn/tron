import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/media_files.dart' as media;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Web: dọn file âm thanh/video kiểu cũ khỏi localStorage trước khi đọc
    // combo, để lần lưu combo sau không bị lỗi đầy bộ nhớ.
    await media.releaseLegacyMediaStorage();
  } catch (_) {
    // Không chuyển được thì vẫn mở app; lần lưu sau sẽ thử lại.
  }
  runApp(const ProviderScope(child: TronApp()));
}
