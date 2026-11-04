import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_loop.dart';
import 'file_service.dart';

/// Tạo player nghe thử âm nền: phát như nhạc thường ra loa, không cần đang
/// trong cuộc gọi.
final backgroundPreviewLoopProvider = Provider<BackgroundLoop Function()>((
  ref,
) {
  final files = ref.watch(fileServiceProvider);
  return () => JustAudioBackgroundLoop(files, inCall: false);
});

/// `true` khi đang nghe thử âm nền.
final backgroundPreviewProvider =
    NotifierProvider<BackgroundPreviewNotifier, bool>(
      BackgroundPreviewNotifier.new,
    );

class BackgroundPreviewNotifier extends Notifier<bool> {
  final _loops = <BackgroundLoop>[];
  int _generation = 0;
  double _volume = 1;

  @override
  bool build() {
    ref.onDispose(() {
      _generation++;
      _release();
    });
    return false;
  }

  /// Phát lặp cùng lúc các âm nền [sources] (khoá âm nền có sẵn hoặc file
  /// riêng) ở mức [volume]. Đang phát thì thay bằng danh sách mới.
  Future<void> play(List<String> sources, double volume) async {
    await stop();
    if (sources.isEmpty) {
      return;
    }
    final generation = _generation;
    final create = ref.read(backgroundPreviewLoopProvider);
    _volume = volume;
    state = true;
    var started = 0;
    for (final source in sources) {
      if (generation != _generation) {
        return;
      }
      final loop = create();
      _loops.add(loop);
      try {
        await loop.start(source, _volume);
        started++;
      } catch (_) {
        if (_loops.remove(loop)) {
          unawaited(loop.dispose().catchError((Object _) {}));
        }
      }
    }
    if (generation == _generation && started == 0) {
      await stop();
      throw StateError('Không phát được âm nền.');
    }
  }

  /// Đổi âm lượng ngay khi đang nghe thử (kéo thanh âm lượng).
  Future<void> setVolume(double volume) async {
    _volume = volume;
    for (final loop in [..._loops]) {
      await loop.setVolume(volume).catchError((Object _) {});
    }
  }

  Future<void> stop() async {
    _generation++;
    if (ref.mounted && state) {
      state = false;
    }
    await _release();
  }

  Future<void> _release() async {
    final loops = [..._loops];
    _loops.clear();
    for (final loop in loops) {
      await loop.dispose().catchError((Object _) {});
    }
  }
}
