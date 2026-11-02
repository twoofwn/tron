import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_settings.dart';
import '../services/sos_message.dart';
import '../services/sos_platform.dart';
import 'sos_providers.dart';

enum SosPhase { countdown, locating, sending, calling, done, cancelled }

enum DeliveryStatus { pending, sending, sent, failed, manual }

@immutable
class SosDelivery {
  const SosDelivery(this.contact, this.status, {this.error});
  final SosContact contact;
  final DeliveryStatus status;
  final String? error;
}

@immutable
class SosAlertState {
  const SosAlertState({
    required this.phase,
    this.secondsLeft = 0,
    this.deliveries = const [],
    this.message,
    this.location,
    this.locationTried = false,
    this.calledIndex,
    this.directCall = false,
    this.settings,
  });

  final SosPhase phase;
  final int secondsLeft;
  final List<SosDelivery> deliveries;
  final String? message;
  final SosLocation? location;

  /// Đã thử lấy vị trí (để phân biệt "đang lấy" với "không lấy được").
  final bool locationTried;

  /// Người cuối cùng đã gọi (vị trí trong danh sách).
  final int? calledIndex;

  /// Lần gọi gần nhất gọi thẳng; false là chỉ mở màn quay số.
  final bool directCall;
  final SosSettings? settings;

  int get sentCount =>
      deliveries.where((item) => item.status == DeliveryStatus.sent).length;

  bool get hasFailures =>
      deliveries.any((item) => item.status == DeliveryStatus.failed);

  /// Còn người chưa gọi để bấm "Gọi người tiếp theo".
  int? get nextCallIndex {
    final next = (calledIndex ?? -1) + 1;
    return next < deliveries.length ? next : null;
  }

  SosAlertState copyWith({
    SosPhase? phase,
    int? secondsLeft,
    List<SosDelivery>? deliveries,
    String? message,
    SosLocation? location,
    bool? locationTried,
    int? calledIndex,
    bool? directCall,
    SosSettings? settings,
  }) => SosAlertState(
    phase: phase ?? this.phase,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    deliveries: deliveries ?? this.deliveries,
    message: message ?? this.message,
    location: location ?? this.location,
    locationTried: locationTried ?? this.locationTried,
    calledIndex: calledIndex ?? this.calledIndex,
    directCall: directCall ?? this.directCall,
    settings: settings ?? this.settings,
  );
}

final sosAlertProvider =
    NotifierProvider.autoDispose<SosAlertController, SosAlertState>(
      SosAlertController.new,
    );

/// Một lần bấm SOS, từ lúc đếm ngược tới màn kết quả.
class SosAlertController extends Notifier<SosAlertState> {
  static const locationTimeout = Duration(seconds: 8);

  Timer? _timer;
  bool _started = false;

  SosPlatform get _platform => ref.read(sosPlatformProvider);
  SosPermissionService get _permissions =>
      ref.read(sosPermissionServiceProvider);

  @override
  SosAlertState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SosAlertState(phase: SosPhase.countdown);
  }

  /// Gọi một lần khi mở màn SOS.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    final settings = await ref.read(sosSettingsProvider.future);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      settings: settings,
      secondsLeft: settings.countdownSeconds,
      deliveries: [
        for (final contact in settings.contacts)
          SosDelivery(contact, DeliveryStatus.pending),
      ],
    );
    if (!settings.isReady) {
      // Chưa có ai để gửi: màn kết quả chỉ còn nút gọi 113 và thiết lập SOS.
      state = state.copyWith(phase: SosPhase.done);
      return;
    }
    if (settings.countdownSeconds <= 0) {
      await _run();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.secondsLeft - 1;
      if (left <= 0) {
        timer.cancel();
        unawaited(_run());
      } else {
        state = state.copyWith(secondsLeft: left);
      }
    });
  }

  /// Bỏ qua đếm ngược, gửi ngay.
  Future<void> sendNow() async {
    if (state.phase != SosPhase.countdown || state.settings == null) {
      return;
    }
    _timer?.cancel();
    await _run();
  }

  void cancel() {
    if (state.phase != SosPhase.countdown) {
      return;
    }
    _timer?.cancel();
    state = state.copyWith(phase: SosPhase.cancelled);
  }

  Future<void> _run() async {
    final settings = state.settings!;
    state = state.copyWith(phase: SosPhase.locating, secondsLeft: 0);

    // Quyền thường đã được cấp ở màn cài đặt SOS; nếu chưa thì hỏi ngay bây giờ.
    var canSms = await _permissions.isGranted(SosPermission.sms);
    if (!canSms) {
      canSms = await _permissions.request(SosPermission.sms);
    }
    if (!await _permissions.isGranted(SosPermission.location)) {
      await _permissions.request(SosPermission.location);
    }
    if (settings.autoCall &&
        !await _permissions.isGranted(SosPermission.call)) {
      await _permissions.request(SosPermission.call);
    }
    if (!ref.mounted) {
      return;
    }

    final location = await _platform.locate(timeout: locationTimeout);
    final battery = await _platform.battery();
    if (!ref.mounted) {
      return;
    }
    final message = SosMessage.render(
      settings.template,
      location: location,
      now: DateTime.now(),
      battery: battery,
      plain: settings.plainText,
    );
    state = state.copyWith(
      phase: SosPhase.sending,
      message: message,
      location: location,
      locationTried: true,
    );

    if (canSms) {
      await Future.wait([
        for (final delivery in state.deliveries) _send(delivery.contact),
      ]);
    } else {
      await _openSmsApp(settings.contacts, message);
    }
    if (!ref.mounted) {
      return;
    }

    if (settings.autoCall && settings.contacts.isNotEmpty) {
      state = state.copyWith(phase: SosPhase.calling);
      await callContact(0);
    }
    if (ref.mounted) {
      state = state.copyWith(phase: SosPhase.done);
    }
  }

  Future<void> _send(SosContact contact) async {
    _setStatus(contact.id, DeliveryStatus.sending);
    final error = await _platform.sendSms(contact.phone, state.message!);
    if (ref.mounted) {
      _setStatus(
        contact.id,
        error == null ? DeliveryStatus.sent : DeliveryStatus.failed,
        error: error,
      );
    }
  }

  /// Không có quyền gửi SMS: mở app tin nhắn soạn sẵn cho mọi người, người dùng tự bấm gửi.
  Future<void> _openSmsApp(List<SosContact> contacts, String message) async {
    final uri = Uri(
      scheme: 'sms',
      path: contacts.map((item) => item.phone).join(','),
      queryParameters: {'body': message},
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    for (final contact in contacts) {
      _setStatus(
        contact.id,
        opened ? DeliveryStatus.manual : DeliveryStatus.failed,
        error: opened ? null : 'permission',
      );
    }
  }

  void _setStatus(String id, DeliveryStatus status, {String? error}) {
    state = state.copyWith(
      deliveries: [
        for (final item in state.deliveries)
          item.contact.id == id
              ? SosDelivery(item.contact, status, error: error)
              : item,
      ],
    );
  }

  Future<void> retry(String contactId) async {
    final delivery = state.deliveries
        .where((item) => item.contact.id == contactId)
        .firstOrNull;
    if (delivery == null || state.message == null) {
      return;
    }
    if (!await _permissions.isGranted(SosPermission.sms) &&
        !await _permissions.request(SosPermission.sms)) {
      await _openSmsApp([delivery.contact], state.message!);
      return;
    }
    await _send(delivery.contact);
  }

  Future<void> callContact(int index) async {
    if (index < 0 || index >= state.deliveries.length) {
      return;
    }
    final direct = await _platform.call(state.deliveries[index].contact.phone);
    if (ref.mounted) {
      state = state.copyWith(calledIndex: index, directCall: direct);
    }
  }

  Future<void> callNext() async {
    final next = state.nextCallIndex;
    if (next != null) {
      await callContact(next);
    }
  }

  Future<void> dialEmergency(String number) => _platform.dial(number);
}
