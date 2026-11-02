import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:tron/features/fake_call/services/reply_listener.dart';
import 'package:tron/features/fake_call/services/turn_detector.dart';

/// Bộ thu giả: test tự đẩy dữ liệu PCM vào luồng.
class FakeRecorder implements AudioRecorder {
  FakeRecorder({this.granted = true});
  bool granted;
  final permissionRequests = <bool>[];
  final configs = <RecordConfig>[];
  int stops = 0;
  StreamController<Uint8List>? audio;
  Completer<void>? holdStart;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    permissionRequests.add(request);
    return granted;
  }

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    configs.add(config);
    await holdStart?.future;
    audio = StreamController<Uint8List>();
    return audio!.stream;
  }

  @override
  Future<String?> stop() async {
    stops++;
    unawaited(audio?.close());
    return null;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 30 ms âm thanh 16 kHz với biên độ cố định (0 là im lặng).
Uint8List _frames(int count, int amplitude) {
  final data = ByteData(count * 480 * 2);
  for (var i = 0; i < count * 480; i++) {
    data.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('opens the mic without changing the call audio', () async {
    final recorder = FakeRecorder();
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    expect(await listener.open(), isTrue);
    expect(recorder.permissionRequests, [false]);
    final config = recorder.configs.single;
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.echoCancel, isTrue);
    expect(config.audioInterruption, AudioInterruptionMode.none);
    expect(
      config.androidConfig.audioSource,
      AndroidAudioSource.voiceCommunication,
    );
    expect(config.androidConfig.manageBluetooth, isFalse);
    expect(config.androidConfig.speakerphone, isFalse);
    expect(config.androidConfig.audioManagerMode, AudioManagerMode.modeNormal);
    await listener.close();
    expect(recorder.stops, 1);
  });

  test('a real call never asks for permission; the preview does', () async {
    final recorder = FakeRecorder(granted: false);
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    expect(await listener.open(), isFalse);
    expect(await listener.open(askPermission: true), isFalse);
    expect(recorder.permissionRequests, [false, true]);
    expect(recorder.configs, isEmpty);
  });

  test('unsupported platforms never touch the mic', () async {
    var created = 0;
    final listener = MicReplyListener(
      createRecorder: () {
        created++;
        return FakeRecorder();
      },
      supported: false,
    );
    expect(await listener.open(askPermission: true), isFalse);
    expect(await listener.hasPermission(request: true), isFalse);
    expect(created, 0);
  });

  test('ends the wait after the user talks and goes quiet', () async {
    final recorder = FakeRecorder();
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    await listener.open();
    final reply = listener.waitForReply(const Duration(seconds: 3));
    expect(listener.listening.value, isTrue);
    // 0,3 s im, 1 s nói, rồi 1 s im.
    recorder.audio!
      ..add(_frames(10, 0))
      ..add(_frames(33, 6000))
      ..add(_frames(34, 0));
    expect(await reply, ReplyOutcome.finished);
    expect(listener.listening.value, isFalse);
    await listener.close();
  });

  test('audio between turns is ignored', () async {
    final recorder = FakeRecorder();
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    await listener.open();
    // Người gọi đang nói: micro nghe tiếng vọng nhưng không có lượt chờ.
    recorder.audio!.add(_frames(40, 6000));
    await Future<void>.delayed(Duration.zero);
    final reply = listener.waitForReply(const Duration(seconds: 3));
    recorder.audio!
      ..add(_frames(30, 6000))
      ..add(_frames(34, 0));
    expect(await reply, ReplyOutcome.finished);
    await listener.close();
  });

  test('hanging up cancels the wait and closes the mic', () async {
    final recorder = FakeRecorder();
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    await listener.open();
    final reply = listener.waitForReply(const Duration(seconds: 3));
    await listener.close();
    expect(await reply, ReplyOutcome.cancelled);
    expect(recorder.stops, 1);
    expect(listener.isOpen, isFalse);
  });

  test('hanging up while the mic is opening leaves it closed', () async {
    final recorder = FakeRecorder()..holdStart = Completer<void>();
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    final opening = listener.open();
    await Future<void>.delayed(Duration.zero);
    await listener.close();
    recorder.holdStart!.complete();
    expect(await opening, isFalse);
    expect(listener.isOpen, isFalse);
    expect(recorder.stops, 1);
  });

  test('a lost mic ends the wait instead of hanging the call', () async {
    final recorder = FakeRecorder();
    final listener = MicReplyListener(
      createRecorder: () => recorder,
      supported: true,
    );
    await listener.open();
    final reply = listener.waitForReply(const Duration(seconds: 3));
    await recorder.audio!.close();
    expect(await reply, ReplyOutcome.noReply);
    expect(listener.isOpen, isFalse);
  });

  test('without a mic it waits the fixed time', () async {
    final listener = MicReplyListener(supported: false);
    final watch = Stopwatch()..start();
    final outcome = await listener.waitForReply(
      const Duration(milliseconds: 50),
    );
    expect(outcome, ReplyOutcome.noReply);
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(45));
  });
}
