import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/fake_call/models/call_script.dart';
import 'package:tron/features/fake_call/services/call_script_runner.dart';
import 'package:tron/features/scenarios/models/scenario.dart';

DialogueStep _say(String id, String text, {String? audio}) => DialogueStep(
  id: id,
  type: DialogueStepType.speech,
  text: text,
  audioPath: audio,
);

DialogueStep _wait(String id, {int seconds = 0}) => DialogueStep(
  id: id,
  type: DialogueStepType.wait,
  text: 'Bạn trả lời',
  seconds: seconds,
);

String _describe(CallScript script) => script.turns
    .map(
      (turn) => switch (turn) {
        SpeakTurn(:final text) => 'say:$text',
        ListenTurn(:final fallback) => 'listen:${fallback.inSeconds}',
      },
    )
    .join(' | ');

void main() {
  group('CallScript.fromSteps', () {
    test('keeps speech and wait steps in order', () {
      final script = CallScript.fromSteps([
        _say('1', 'Alo, con à?', audio: 'audio/voice/mother_1.wav'),
        _wait('w1'),
        _say('2', 'Về ngay nhé.'),
        _say('3', 'Nhanh lên.'),
      ]);
      expect(
        _describe(script),
        'say:Alo, con à? | listen:3 | say:Về ngay nhé. | say:Nhanh lên.',
      );
      expect(
        (script.turns.first as SpeakTurn).audioPath,
        'audio/voice/mother_1.wav',
      );
    });

    test('merges repeated waits, drops a trailing wait and empty lines', () {
      final script = CallScript.fromSteps([
        _wait('w0', seconds: 2),
        _say('1', 'Alo?'),
        _wait('w1'),
        _wait('w2', seconds: 6),
        _say('2', '   '),
        _say('3', 'Xong rồi.'),
        _wait('w3'),
      ]);
      expect(
        _describe(script),
        'listen:2 | say:Alo? | listen:6 | say:Xong rồi.',
      );
    });

    test('a line with audio but no text is kept', () {
      final script = CallScript.fromSteps([
        _say('1', '', audio: '/data/user/0/app/voice.m4a'),
      ]);
      expect(script.lines.single.audioPath, '/data/user/0/app/voice.m4a');
    });
  });

  group('CallScript.fromText', () {
    test('splits sentences and waits between them', () {
      final script = CallScript.fromText(
        'Alo, em nghe không? Server sập rồi! Vào họp gấp nhé…  Cảm ơn',
      );
      expect(
        _describe(script),
        'say:Alo, em nghe không? | listen:3 | say:Server sập rồi! | listen:3 '
        '| say:Vào họp gấp nhé… | listen:3 | say:Cảm ơn',
      );
    });

    test('empty text gives an empty script', () {
      expect(CallScript.fromText('  ').isEmpty, isTrue);
    });
  });

  group('CallScriptRunner', () {
    test('speaks, waits for the reply, then goes on', () async {
      final log = <String>[];
      final reply = Completer<void>();
      final runner = CallScriptRunner(
        speak: (line) async => log.add('say:${line.text}'),
        waitForReply: (fallback) {
          log.add('listen:${fallback.inSeconds}');
          return reply.future;
        },
        isCancelled: () => false,
        pause: (duration) async => log.add('pause:${duration.inMilliseconds}'),
      );
      final done = runner.run(
        CallScript.fromSteps([
          _say('1', 'Alo?'),
          _wait('w'),
          _say('2', 'Về ngay.'),
          _say('3', 'Nhanh.'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(log, ['say:Alo?', 'listen:3']);
      reply.complete();
      await done;
      expect(log, [
        'say:Alo?',
        'listen:3',
        'say:Về ngay.',
        'pause:300',
        'say:Nhanh.',
      ]);
    });

    test('stops when the call ends during a wait', () async {
      final log = <String>[];
      var cancelled = false;
      final runner = CallScriptRunner(
        speak: (line) async => log.add(line.text),
        waitForReply: (_) async => cancelled = true,
        isCancelled: () => cancelled,
        pause: (_) async {},
      );
      await runner.run(CallScript.fromText('Một. Hai. Ba.'));
      expect(log, ['Một.']);
    });
  });
}
