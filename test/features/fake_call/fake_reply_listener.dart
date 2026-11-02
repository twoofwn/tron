import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tron/features/fake_call/services/reply_listener.dart';
import 'package:tron/features/fake_call/services/turn_detector.dart';

/// Micro giả: test tự quyết định khi nào người dùng "nói xong".
class FakeReplyListener implements ReplyListener {
  FakeReplyListener({this.supported = true, this.granted = true});

  final bool supported;
  bool granted;
  final events = <String>[];
  final _listening = ValueNotifier(false);
  Completer<ReplyOutcome>? _pending;

  bool get isWaiting => _pending != null;

  @override
  ValueListenable<bool> get listening => _listening;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasPermission({bool request = false}) async {
    events.add('permission:$request');
    return supported && granted;
  }

  @override
  Future<bool> open({bool askPermission = false}) async {
    events.add('open:$askPermission');
    return supported && granted;
  }

  @override
  Future<ReplyOutcome> waitForReply(Duration fallback) {
    events.add('wait');
    _listening.value = true;
    return (_pending = Completer<ReplyOutcome>()).future;
  }

  void reply([ReplyOutcome outcome = ReplyOutcome.finished]) {
    _listening.value = false;
    final pending = _pending;
    _pending = null;
    pending?.complete(outcome);
  }

  @override
  Future<void> close() async {
    events.add('close');
    reply(ReplyOutcome.cancelled);
  }

  @override
  void dispose() {}
}
