import 'package:tron/core/services/background_loop.dart';

/// Âm nền giả: ghi lại việc phát, đổi âm lượng và giải phóng.
class FakeLoop implements BackgroundLoop {
  FakeLoop({this.broken = false});
  final bool broken;
  String? source;
  double? volume;
  bool disposed = false;

  @override
  Future<void> start(String source, double volume) async {
    if (broken) {
      throw StateError('Không mở được $source');
    }
    this.source = source;
    this.volume = volume;
  }

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> dispose() async => disposed = true;
}

/// Tạo [FakeLoop] và giữ lại để kiểm tra. Âm nền thứ i (tính từ 0) nằm
/// trong [brokenSources] thì không mở được.
class LoopFactory {
  LoopFactory({this.brokenSources = const {}});
  final Set<int> brokenSources;
  final loops = <FakeLoop>[];

  BackgroundLoop call() {
    final loop = FakeLoop(broken: brokenSources.contains(loops.length));
    loops.add(loop);
    return loop;
  }
}
