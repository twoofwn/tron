import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_foreground_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../core/services/audio_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../activation/services/call_alarm_service.dart';
import '../../combo/models/combo_model.dart';
import '../../scenarios/data/scenario_lookup.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/call_script.dart';
import '../providers/call_provider.dart';
import '../services/call_device_service.dart';
import '../services/reply_listener.dart';
import '../themes/call_theme.dart';
import '../widgets/in_call_view.dart';
import '../widgets/incoming/messenger_incoming_view.dart';
import '../widgets/messenger_in_call_view.dart';
import '../widgets/zalo_in_call_view.dart';
import '../widgets/incoming/phone_incoming_view.dart';
import '../widgets/incoming/zalo_incoming_view.dart';
import '../widgets/video_in_call_view.dart';

final callSessionProvider =
    NotifierProvider.autoDispose<CallSessionNotifier, CallStatus>(
      CallSessionNotifier.new,
    );

class CallSessionNotifier extends Notifier<CallStatus> {
  @override
  CallStatus build() => CallStatus.ringing;
  void answer() => state = CallStatus.inProgress;
}

class FakeCallArguments {
  const FakeCallArguments(this.combo, {this.isPreview = true});
  final ComboModel combo;
  final bool isPreview;
}

class FakeCallScreen extends ConsumerStatefulWidget {
  const FakeCallScreen({super.key, required this.arguments});
  final FakeCallArguments arguments;
  @override
  ConsumerState<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends ConsumerState<FakeCallScreen> {
  Timer? _timer;
  Timer? _vibration;
  final _ringStartedAt = DateTime.now();
  bool _waitingForForeground = false;
  DateTime? _answeredAt;
  Duration _elapsed = Duration.zero;
  bool _isMuted = false;
  bool _isSpeaker = false;
  // Đã bấm phím âm lượng: chuông im nhưng màn gọi vẫn chờ trả lời.
  bool _ringSilenced = false;
  late final CallDeviceService _device;
  late final ReplyListener _replies;
  // Micro mở xong (hoặc không mở được) thì mới bắt đầu nghe lượt chờ đầu tiên.
  Future<bool>? _micReady;
  StreamSubscription<void>? _volumeKeys;

  ComboModel get _combo => widget.arguments.combo;
  ScenarioInfo get _scenario => ScenarioLookup.resolve(
    _combo.scenarioId,
    ref.read(scenarioLibraryProvider).value,
  );
  CallScript get _script => _scenario.script;

  @override
  void initState() {
    super.initState();
    _device = ref.read(callDeviceServiceProvider);
    _replies = ref.read(replyListenerProvider);
    _volumeKeys = _device.volumeKeyPresses.listen((_) => _silenceRinging());
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vibration?.cancel();
    unawaited(_volumeKeys?.cancel());
    unawaited(_device.setSilenceKeys(false));
    unawaited(_replies.close());
    // Màn gọi đóng mà chưa qua nút Kết thúc: vẫn trả âm thanh về bình thường.
    if (_answeredAt != null) {
      unawaited(_device.endCallAudio());
    }
    // Trả thanh điều hướng về màu mặc định, không để màu màn gọi dính sang trang chủ.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Colors.black),
    );
    super.dispose();
  }

  Future<void> _startRinging() async {
    final vibrate = ref.read(settingsProvider).value?.vibrateOnCall ?? true;
    if (vibrate) {
      _vibration = Timer.periodic(
        const Duration(milliseconds: 1200),
        (_) => HapticFeedback.heavyImpact(),
      );
    }
    unawaited(_device.setSilenceKeys(true));
    // Combo chưa thu giọng: tạo trước giọng đọc để trả lời là nghe ngay.
    if (_combo.voicePath == null) {
      unawaited(
        ref
            .read(audioServiceProvider)
            .prepareSpeech(_script)
            .catchError((Object _) {}),
      );
    }
    // Máy khóa hoặc app ở nền: thông báo hệ thống đang đổ chuông. App chờ
    // tới khi lên màn hình mới đổ chuông để không phát chồng hai chuông.
    if (!widget.arguments.isPreview && !ref.read(appForegroundProvider)) {
      _waitingForForeground = true;
      return;
    }
    await _playRingtone();
  }

  void _onForegroundChanged(bool? previous, bool foreground) {
    if (!foreground ||
        !_waitingForForeground ||
        ref.read(callSessionProvider) != CallStatus.ringing) {
      return;
    }
    _waitingForForeground = false;
    // Thông báo đã tự tắt sau thời gian chờ: coi như cuộc gọi nhỡ.
    if (DateTime.now().difference(_ringStartedAt) >
        CallAlarmService.ringTimeout) {
      unawaited(_hangUp());
      return;
    }
    ref.read(callProvider.notifier).silenceAlarm();
    unawaited(_playRingtone());
  }

  Future<void> _playRingtone() async {
    final phoneStyle = await _phoneStyle();
    // Người dùng có thể đã trả lời, tắt chuông hoặc tắt máy trong lúc đọc cài đặt.
    if (!mounted ||
        _ringSilenced ||
        ref.read(callSessionProvider) != CallStatus.ringing) {
      return;
    }
    try {
      await ref.read(audioServiceProvider).ring(_combo, phoneStyle: phoneStyle);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không phát được chuông trên thiết bị này.');
      }
    }
  }

  /// Như máy thật: bấm phím âm lượng lúc đổ chuông thì chuông và rung im,
  /// cuộc gọi vẫn chờ trả lời hoặc từ chối.
  void _silenceRinging() {
    if (!mounted ||
        _ringSilenced ||
        ref.read(callSessionProvider) != CallStatus.ringing) {
      return;
    }
    _ringSilenced = true;
    _vibration?.cancel();
    if (!widget.arguments.isPreview) {
      ref.read(callProvider.notifier).silenceAlarm();
    }
    unawaited(ref.read(audioServiceProvider).stop());
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeaker = !_isSpeaker);
    await _device.setSpeaker(_isSpeaker);
  }

  Future<PhoneStyle> _phoneStyle() async {
    try {
      return await ref.read(resolvedPhoneStyleProvider.future);
    } catch (_) {
      return PhoneStyle.samsung;
    }
  }

  Future<void> _answer() async {
    // Chặn trả lời hai lần (ví dụ chạm nhanh hai lần) để không tạo hai đồng hồ.
    if (ref.read(callSessionProvider) == CallStatus.inProgress) {
      return;
    }
    _vibration?.cancel();
    ref.read(callSessionProvider.notifier).answer();
    if (!widget.arguments.isPreview) {
      ref.read(callProvider.notifier).answer();
    }
    _answeredAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_answeredAt!));
      }
    });
    // Trong cuộc gọi, phím âm lượng chỉnh âm lượng cuộc gọi như bình thường.
    await _device.setSilenceKeys(false);
    await _device.startCallAudio(speaker: _isSpeaker);
    if (!mounted) {
      return;
    }
    // Gọi video không có thoại: có video thì video tự phát tiếng; không có
    // hoặc video hỏng thì người gọi "tắt camera" và im. Chỉ tắt chuông.
    await _playConversation(withVoice: !_combo.isVideoCall);
  }

  Future<void> _playConversation({bool withVoice = true}) async {
    // Giọng thu liền một file thì phát cả file, không có lượt chờ nên không
    // cần micro.
    final listen =
        withVoice &&
        _combo.voicePath == null &&
        (ref.read(settingsProvider).value?.waitForReply ?? true);
    if (listen) {
      // Bản xem thử được hỏi quyền micro; cuộc gọi thật thì không, vì hộp
      // thoại xin quyền sẽ làm lộ cuộc gọi giả.
      _micReady ??= _replies.open(askPermission: widget.arguments.isPreview);
    }
    try {
      await ref
          .read(audioServiceProvider)
          .conversation(
            _combo,
            _script,
            withVoice: withVoice,
            waitForReply: listen ? _waitForReply : null,
            backgroundVolume:
                ref.read(settingsProvider).value?.backgroundVolume ??
                AppSettings.defaultBackgroundVolume,
          );
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Không phát được hội thoại. Kiểm tra giọng tiếng Việt của thiết bị.',
        );
      }
    }
  }

  /// Lượt chờ người dùng đáp. Đang tắt tiếng thì người gọi không nghe được
  /// mình, nên chờ theo thời gian cố định.
  Future<void> _waitForReply(Duration fallback) async {
    await _micReady;
    if (!mounted) {
      return;
    }
    if (_isMuted) {
      await Future<void>.delayed(fallback);
      return;
    }
    await _replies.waitForReply(
      fallback,
      endSilence:
          ref.read(settingsProvider).value?.replyPause ??
          AppSettings.defaultReplyPause,
    );
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _vibration?.cancel();
    if (!widget.arguments.isPreview) {
      ref.read(callProvider.notifier).cancel();
    }
    await _replies.close();
    await ref.read(audioServiceProvider).stop();
    await _device.setSilenceKeys(false);
    if (_answeredAt != null) {
      await _device.endCallAudio();
    }
  }

  void _toggleMute() => setState(() => _isMuted = !_isMuted);

  Future<void> _hangUp() async {
    await _stop();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Giữ nút gác máy: kết thúc cuộc gọi giả và mở màn SOS (bản xem thử thì không).
  Future<void> _startSos() async {
    if (widget.arguments.isPreview) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    await _stop();
    if (mounted) {
      unawaited(Navigator.pushReplacementNamed(context, RouteNames.sosAlert));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appForegroundProvider, _onForegroundChanged);
    final combo = _combo;
    final theme = CallTheme.of(combo.callInterface);
    final isAnswered = ref.watch(callSessionProvider) == CallStatus.inProgress;
    final caller = combo.displayCaller(
      ScenarioLookup.resolve(
        combo.scenarioId,
        ref.watch(scenarioLibraryProvider).value,
      ).caller,
    );
    final initial = caller.isEmpty
        ? '?'
        : caller.characters.first.toUpperCase();
    final isVideo = combo.isVideoCall;
    // Đang gọi video: video người gọi phủ kín màn hình, không đóng khung như gọi thoại.
    if (isAnswered && isVideo) {
      return _CallScaffold(
        theme: theme,
        onPop: _stop,
        child: VideoInCallView(
          caller: caller,
          initial: initial,
          theme: theme,
          elapsed: _elapsed,
          videoPath: combo.videoPath,
          loop: combo.videoEndAction == VideoEndAction.loop,
          isMuted: _isMuted,
          onToggleMute: () => setState(() => _isMuted = !_isMuted),
          onHangUp: _hangUp,
          onSos: _startSos,
          // Hết video (khi không lặp): người gọi gác máy.
          onVideoEnded: _hangUp,
          onVideoUnavailable: () => showMessage(
            context,
            'Không phát được video người gọi trên thiết bị này.',
          ),
        ),
      );
    }
    // Zalo và Messenger: dựng như app thật trên Android, phủ kín màn hình,
    // font của hệ thống.
    if (combo.callInterface != CallInterface.phone) {
      return _appStyleCall(
        theme: theme,
        isAnswered: isAnswered,
        caller: caller,
        initial: initial,
        isVideo: isVideo,
      );
    }
    final Widget view;
    if (isAnswered) {
      view = InCallView(
        caller: caller,
        theme: theme,
        elapsed: _elapsed,
        isMuted: _isMuted,
        isSpeaker: _isSpeaker,
        // Như máy thật: tắt tiếng chỉ tắt mic của mình, vẫn nghe người gọi.
        onToggleMute: () => setState(() => _isMuted = !_isMuted),
        onToggleSpeaker: _toggleSpeaker,
        onHangUp: _hangUp,
        onSos: _startSos,
        statusHint: widget.arguments.isPreview
            ? _ListeningHint(_replies.listening)
            : null,
      );
    } else {
      view = switch (combo.callInterface) {
        CallInterface.phone => PhoneIncomingView(
          caller: caller,
          initial: initial,
          theme: theme,
          isVideo: isVideo,
          onAnswer: _answer,
          onDecline: _hangUp,
        ),
        // Zalo/Messenger đã trả về ở trên.
        CallInterface.zalo || CallInterface.messenger => const SizedBox(),
      };
    }
    return _CallScaffold(
      theme: theme,
      onPop: _stop,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (widget.arguments.isPreview)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'XEM TRƯỚC CUỘC GỌI',
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 2,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(child: view),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on _FakeCallScreenState {
  Widget _appStyleCall({
    required CallTheme theme,
    required bool isAnswered,
    required String caller,
    required String initial,
    required bool isVideo,
  }) {
    final isZalo = _combo.callInterface == CallInterface.zalo;
    final Widget content;
    final Color background;
    Widget? backdrop;
    if (!isAnswered) {
      // Android: Zalo/Messenger tự vẽ màn gọi đến, cùng nền với màn đang gọi.
      background = isZalo
          ? ZaloInCallView.background
          : MessengerInCallView.background;
      backdrop = isZalo ? null : const _MessengerBackdrop();
      content = isZalo
          ? ZaloIncomingView(
              caller: caller,
              initial: initial,
              theme: theme,
              isVideo: isVideo,
              onAnswer: _answer,
              onDecline: _hangUp,
            )
          : MessengerIncomingView(
              caller: caller,
              initial: initial,
              theme: theme,
              isVideo: isVideo,
              onAnswer: _answer,
              onDecline: _hangUp,
            );
    } else {
      final hint = widget.arguments.isPreview
          ? _ListeningHint(_replies.listening)
          : null;
      if (isZalo) {
        background = ZaloInCallView.background;
        content = ZaloInCallView(
          caller: caller,
          elapsed: _elapsed,
          isMuted: _isMuted,
          isSpeaker: _isSpeaker,
          onToggleMute: _toggleMute,
          onToggleSpeaker: _toggleSpeaker,
          onHangUp: _hangUp,
          onSos: _startSos,
          statusHint: hint,
        );
      } else {
        background = MessengerInCallView.background;
        backdrop = const _MessengerBackdrop();
        content = MessengerInCallView(
          caller: caller,
          initial: initial,
          elapsed: _elapsed,
          isMuted: _isMuted,
          isSpeaker: _isSpeaker,
          onToggleMute: _toggleMute,
          onToggleSpeaker: _toggleSpeaker,
          onHangUp: _hangUp,
          onSos: _startSos,
          statusHint: hint,
        );
      }
    }
    return _CallScaffold(
      theme: theme,
      onPop: _stop,
      background: background,
      backdrop: backdrop,
      systemFont: true,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: content),
            if (widget.arguments.isPreview)
              const Positioned(
                left: 0,
                right: 0,
                top: 4,
                child: Text(
                  'XEM TRƯỚC CUỘC GỌI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nền tối mờ của màn đang gọi Messenger (ảnh đại diện làm mờ).
class _MessengerBackdrop extends StatelessWidget {
  const _MessengerBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A3150), Color(0xFF1B1726), Color(0xFF0E0C12)],
      ),
    ),
  );
}

/// Khung chung của màn gọi: thanh trạng thái trong suốt để nền phủ kín màn
/// hình như app gọi thật, font cuộc gọi, và dừng âm thanh khi vuốt quay lại.
class _CallScaffold extends StatelessWidget {
  const _CallScaffold({
    required this.theme,
    required this.onPop,
    required this.child,
    this.background,
    this.backdrop,
    this.systemFont = false,
  });
  final CallTheme theme;
  final VoidCallback onPop;
  final Widget child;

  /// Màu nền (và thanh điều hướng); mặc định theo [theme].
  final Color? background;

  /// Lớp nền vẽ phía sau nội dung (ví dụ nền mờ của iOS).
  final Widget? backdrop;

  /// Dùng font của hệ thống (SF trên iPhone, Roboto trên Android) như app thật.
  final bool systemFont;

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        onPop();
      }
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background ?? theme.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background ?? theme.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ?backdrop,
            systemFont
                ? DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    child: child,
                  )
                : DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontFamily: CallTheme.fontFamily,
                      color: Colors.white,
                    ),
                    child: child,
                  ),
          ],
        ),
      ),
    ),
  );
}

/// Bản xem thử: cho biết app đang chờ người dùng nói, để thử ngưỡng chuyển
/// lượt. Cuộc gọi thật không hiện gì.
class _ListeningHint extends StatelessWidget {
  const _ListeningHint(this.listening);
  final ValueListenable<bool> listening;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: listening,
    builder: (context, on, _) => AnimatedOpacity(
      opacity: on ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded, size: 14, color: Colors.greenAccent),
          SizedBox(width: 4),
          Text(
            'Đang nghe bạn…',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
