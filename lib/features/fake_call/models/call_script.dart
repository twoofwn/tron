import 'package:flutter/foundation.dart';

import '../../scenarios/models/scenario.dart';

/// Một lượt trong cuộc gọi giả: người gọi nói một câu, hoặc chờ người dùng đáp.
@immutable
sealed class CallTurn {
  const CallTurn();
}

/// Người gọi nói một câu. Có [audioPath] thì phát file đó, không thì đọc [text].
class SpeakTurn extends CallTurn {
  const SpeakTurn(this.text, {this.audioPath});
  final String text;
  final String? audioPath;
}

/// Chờ người dùng nói xong. Không nghe được micro thì chờ [fallback].
class ListenTurn extends CallTurn {
  const ListenTurn({this.fallback = defaultFallback});
  final Duration fallback;

  static const defaultFallback = Duration(seconds: 3);
}

/// Kịch bản cuộc gọi dạng từng lượt, dùng cho việc chờ người dùng đáp.
@immutable
class CallScript {
  const CallScript(this.turns);

  /// Từ các bước của kịch bản: câu thoại thành lượt nói, bước chờ thành lượt
  /// nghe. Bỏ câu trống, gộp các bước chờ liền nhau, bỏ bước chờ ở cuối vì
  /// sau đó người gọi không còn gì để nói.
  factory CallScript.fromSteps(List<DialogueStep> steps) {
    final turns = <CallTurn>[];
    for (final step in steps) {
      switch (step.type) {
        case DialogueStepType.speech:
          final text = step.text.trim();
          final audio = step.audioPath?.trim();
          if (text.isEmpty && (audio == null || audio.isEmpty)) {
            continue;
          }
          turns.add(
            SpeakTurn(
              text,
              audioPath: audio == null || audio.isEmpty ? null : audio,
            ),
          );
        case DialogueStepType.wait:
          final fallback = step.seconds > 0
              ? Duration(seconds: step.seconds)
              : ListenTurn.defaultFallback;
          final last = turns.lastOrNull;
          if (last is ListenTurn) {
            turns[turns.length - 1] = ListenTurn(
              fallback: last.fallback > fallback ? last.fallback : fallback,
            );
          } else {
            turns.add(ListenTurn(fallback: fallback));
          }
      }
    }
    while (turns.lastOrNull is ListenTurn) {
      turns.removeLast();
    }
    return CallScript(List.unmodifiable(turns));
  }

  /// Kịch bản cũ chỉ có một đoạn chữ: tách theo dấu kết câu và chờ người
  /// dùng đáp sau mỗi câu.
  factory CallScript.fromText(String dialogue) {
    final sentences = splitSentences(dialogue);
    final turns = <CallTurn>[];
    for (final sentence in sentences) {
      if (turns.isNotEmpty) {
        turns.add(const ListenTurn());
      }
      turns.add(SpeakTurn(sentence));
    }
    return CallScript(List.unmodifiable(turns));
  }

  final List<CallTurn> turns;

  Iterable<SpeakTurn> get lines => turns.whereType<SpeakTurn>();

  bool get isEmpty => lines.isEmpty;

  /// Tách đoạn chữ thành câu theo `. ! ? …`, giữ dấu ở cuối câu.
  static List<String> splitSentences(String text) => [
    for (final match in _sentence.allMatches(text))
      if (match.group(0)!.trim().isNotEmpty) match.group(0)!.trim(),
  ];

  static final _sentence = RegExp(r'[^.!?…]+(?:[.!?…]+|$)');
}
