import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/fake_call/services/turn_detector.dart';

const _frame = Duration(milliseconds: 30);
const _quiet = -62.0;
const _voice = -30.0;

/// Đưa [duration] khung cùng một mức vào detector, trả về kết quả đầu tiên
/// cùng thời điểm (tính từ đầu lượt) lúc có kết quả.
({ReplyOutcome? outcome, Duration at}) _feed(
  TurnDetector detector,
  List<(double, Duration)> parts,
) {
  var at = Duration.zero;
  for (final (level, duration) in parts) {
    for (var t = Duration.zero; t < duration; t += _frame) {
      at += _frame;
      final outcome = detector.addLevel(level, _frame);
      if (outcome != null) {
        return (outcome: outcome, at: at);
      }
    }
  }
  return (outcome: null, at: at);
}

Duration _ms(int value) => Duration(milliseconds: value);

void main() {
  group('TurnDetector', () {
    test('finishes about 0.9 s after the user stops talking', () {
      final detector = TurnDetector(noiseFloor: _quiet);
      final result = _feed(detector, [
        (_quiet, _ms(600)),
        (_voice, _ms(1500)),
        (_quiet, _ms(3000)),
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      expect(detector.heardSpeech, isTrue);
      // Hết giọng ở 2,1 s; im 0,9 s nữa thì tới lượt người gọi.
      expect(result.at.inMilliseconds, inInclusiveRange(2970, 3060));
    });

    test('waits the pause chosen in settings after the user stops', () {
      for (final (pause, from, to) in [
        (_ms(500), 2570, 2660),
        (_ms(2000), 4070, 4160),
        (_ms(5000), 7070, 7160),
      ]) {
        final detector = TurnDetector(noiseFloor: _quiet)
          ..reset(endSilence: pause);
        final result = _feed(detector, [
          (_quiet, _ms(600)),
          (_voice, _ms(1500)),
          (_quiet, _ms(8000)),
        ]);
        expect(result.outcome, ReplyOutcome.finished, reason: '$pause');
        // Hết giọng ở 2,1 s; im đúng khoảng đã chọn thì tới lượt người gọi.
        expect(
          result.at.inMilliseconds,
          inInclusiveRange(from, to),
          reason: '$pause',
        );
      }
    });

    test('a long pause does not end the turn when the user keeps talking', () {
      final detector = TurnDetector(noiseFloor: _quiet)
        ..reset(endSilence: _ms(2000));
      final result = _feed(detector, [
        (_quiet, _ms(400)),
        (_voice, _ms(900)),
        (_quiet, _ms(1500)),
        (_voice, _ms(900)),
        (_quiet, _ms(4000)),
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      // Ngừng 1,5 s giữa câu vẫn chưa đủ 2 s nên chưa cắt lời.
      expect(result.at.inMilliseconds, inInclusiveRange(5670, 5760));
    });

    test('short clicks while the user is silent do not restart the pause', () {
      final detector = TurnDetector(noiseFloor: _quiet)
        ..reset(endSilence: _ms(3000));
      // Sau khi nói xong: cứ 0,8 s lại có một tiếng cạch 90 ms (quạt, vọng).
      final quietWithClicks = <(double, Duration)>[
        for (var i = 0; i < 8; i++) ...[(_quiet, _ms(720)), (_voice, _ms(90))],
      ];
      final result = _feed(detector, [
        (_quiet, _ms(600)),
        (_voice, _ms(1500)),
        ...quietWithClicks,
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      // Hết giọng ở 2,1 s; vẫn tới lượt người gọi sau khoảng 3 s.
      expect(result.at.inMilliseconds, inInclusiveRange(5070, 5160));
    });

    test('fast choppy speech is not mistaken for silence', () {
      final detector = TurnDetector(noiseFloor: _quiet)
        ..reset(endSilence: _ms(1000));
      // Nói nhanh từng tiếng: 150 ms có giọng, nghỉ 60 ms giữa các tiếng, 3 s.
      final choppy = <(double, Duration)>[
        for (var i = 0; i < 15; i++) ...[(_voice, _ms(150)), (_quiet, _ms(60))],
      ];
      final result = _feed(detector, [
        (_quiet, _ms(600)),
        (_voice, _ms(600)),
        ...choppy,
        (_quiet, _ms(3000)),
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      // Hết nói ở 4,35 s; chỉ tới lượt người gọi sau đó, không cắt giữa chừng.
      expect(result.at.inMilliseconds, greaterThan(4350));
    });

    test('speaking again for a moment does restart the pause', () {
      final detector = TurnDetector(noiseFloor: _quiet)
        ..reset(endSilence: _ms(3000));
      final result = _feed(detector, [
        (_quiet, _ms(600)),
        (_voice, _ms(1500)),
        (_quiet, _ms(2000)),
        (_voice, _ms(600)),
        (_quiet, _ms(5000)),
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      // Nói lại 0,6 s ở 4,1–4,7 s: đếm lại 3 s từ 4,7 s.
      expect(result.at.inMilliseconds, inInclusiveRange(7670, 7760));
    });

    test('short pauses inside a reply do not end the turn', () {
      final detector = TurnDetector(noiseFloor: _quiet);
      final result = _feed(detector, [
        (_quiet, _ms(400)),
        (_voice, _ms(900)),
        (_quiet, _ms(500)),
        (_voice, _ms(900)),
        (_quiet, _ms(2000)),
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      expect(result.at.inMilliseconds, inInclusiveRange(3570, 3660));
    });

    test('a cough or click shorter than 0.2 s is ignored', () {
      final detector = TurnDetector(noiseFloor: _quiet);
      final result = _feed(detector, [
        (_quiet, _ms(1000)),
        (_voice, _ms(120)),
        (_quiet, _ms(6000)),
      ]);
      expect(result.outcome, ReplyOutcome.noReply);
      expect(detector.heardSpeech, isFalse);
      expect(result.at.inMilliseconds, inInclusiveRange(4980, 5040));
    });

    test('the caller goes on after 5 s of silence', () {
      final detector = TurnDetector(noiseFloor: _quiet);
      final result = _feed(detector, [(_quiet, _ms(8000))]);
      expect(result.outcome, ReplyOutcome.noReply);
      expect(result.at.inMilliseconds, inInclusiveRange(4980, 5040));
    });

    test('endless talking or noise is cut after 20 s', () {
      final detector = TurnDetector(noiseFloor: _quiet);
      final result = _feed(detector, [
        (_quiet, _ms(600)),
        for (var i = 0; i < 70; i++) ...[(_voice, _ms(300)), (-45, _ms(150))],
      ]);
      expect(result.outcome, ReplyOutcome.tooLong);
      expect(result.at.inMilliseconds, inInclusiveRange(20600, 21000));
    });

    test('the caller echo right after a line is not taken as a reply', () {
      final detector = TurnDetector(noiseFloor: _quiet);
      final result = _feed(detector, [(_voice, _ms(240)), (_quiet, _ms(6000))]);
      expect(result.outcome, ReplyOutcome.noReply);
      expect(detector.heardSpeech, isFalse);
    });

    test('steady background noise is learned and not taken as speech', () {
      final detector = TurnDetector(noiseFloor: -70);
      // Quán cà phê ồn đều ở -45 dBFS, người dùng nói to hơn hẳn.
      final result = _feed(detector, [
        (-45, _ms(1500)),
        (-25, _ms(1000)),
        (-45, _ms(3000)),
      ]);
      expect(result.outcome, ReplyOutcome.finished);
      expect(detector.noiseFloor, closeTo(-45, 3));
      expect(result.at.inMilliseconds, inInclusiveRange(3370, 3460));
    });

    test('reset starts a new turn but keeps the learned noise floor', () {
      final detector = TurnDetector(noiseFloor: -70);
      _feed(detector, [(-50, _ms(5000))]);
      final floor = detector.noiseFloor;
      detector.reset();
      expect(detector.heardSpeech, isFalse);
      expect(detector.noiseFloor, floor);
      final result = _feed(detector, [(-50, _ms(6000))]);
      expect(result.outcome, ReplyOutcome.noReply);
    });
  });

  group('PcmLevelMeter', () {
    Uint8List tone(int samples, int amplitude) {
      final data = ByteData(samples * 2);
      for (var i = 0; i < samples; i++) {
        final value = (amplitude * math.sin(i / 8)).round();
        data.setInt16(i * 2, value, Endian.little);
      }
      return data.buffer.asUint8List();
    }

    test('splits arbitrary chunks into 30 ms frames', () {
      final meter = PcmLevelMeter();
      // 480 mẫu mỗi khung ở 16 kHz.
      final audio = tone(480 * 3 + 100, 8000);
      final first = meter.add(Uint8List.sublistView(audio, 0, 1001));
      final rest = meter.add(Uint8List.sublistView(audio, 1001));
      expect(first, hasLength(1));
      expect(rest, hasLength(2));
    });

    test('measures loudness in dBFS', () {
      final meter = PcmLevelMeter();
      final loud = meter.add(tone(480, 16384)).single;
      final soft = meter.add(tone(480, 164)).single;
      final silent = meter.add(Uint8List(960)).single;
      expect(loud, closeTo(-9, 1.5));
      expect(soft, closeTo(-49, 1.5));
      expect(silent, PcmLevelMeter.silence);
    });
  });
}
