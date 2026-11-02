import '../models/call_script.dart';

/// Chờ người dùng đáp xong. [fallback] là thời gian chờ khi không nghe được.
typedef ReplyWaiter = Future<void> Function(Duration fallback);

/// Chạy kịch bản theo lượt: nói một câu, chờ người dùng đáp, nói câu tiếp.
class CallScriptRunner {
  const CallScriptRunner({
    required this.speak,
    required this.waitForReply,
    required this.isCancelled,
    this.pause = _delay,
    this.linePause = const Duration(milliseconds: 300),
  });

  /// Nói một câu và chờ tới khi nói xong.
  final Future<void> Function(SpeakTurn line) speak;
  final ReplyWaiter waitForReply;

  /// Cuộc gọi đã kết thúc hoặc chuyển sang hội thoại khác.
  final bool Function() isCancelled;
  final Future<void> Function(Duration) pause;

  /// Khoảng nghỉ giữa hai câu liền nhau của người gọi.
  final Duration linePause;

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);

  Future<void> run(CallScript script) async {
    CallTurn? previous;
    for (final turn in script.turns) {
      if (isCancelled()) {
        return;
      }
      switch (turn) {
        case SpeakTurn():
          if (previous is SpeakTurn) {
            await pause(linePause);
            if (isCancelled()) {
              return;
            }
          }
          await speak(turn);
        case ListenTurn():
          await waitForReply(turn.fallback);
      }
      previous = turn;
    }
  }
}
