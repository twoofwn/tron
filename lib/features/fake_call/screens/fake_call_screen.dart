import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../combo/models/combo_model.dart';
import '../../scenarios/data/scenario_lookup.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/call_provider.dart';
import '../themes/call_theme.dart';
import '../widgets/in_call_view.dart';
import '../widgets/incoming/messenger_incoming_view.dart';
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
  DateTime? _answeredAt;
  Duration _elapsed = Duration.zero;
  bool _isMuted = false;
  bool _isSpeaker = false;

  ComboModel get _combo => widget.arguments.combo;
  ScenarioInfo get _scenario => ScenarioLookup.resolve(
    _combo.scenarioId,
    ref.read(scenarioLibraryProvider).value,
  );
  String get _dialogue => _scenario.dialogue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vibration?.cancel();
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
    try {
      await ref.read(audioServiceProvider).ring(_combo);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không phát được chuông trên thiết bị này.');
      }
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
    // Gọi video có video người gọi: video tự phát tiếng, chỉ tắt chuông.
    await _playConversation(
      withVoice: !(_combo.isVideoCall && _combo.videoPath != null),
    );
  }

  Future<void> _playConversation({bool withVoice = true}) async {
    try {
      await ref
          .read(audioServiceProvider)
          .conversation(_combo, _dialogue, withVoice: withVoice);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Không phát được hội thoại. Kiểm tra giọng tiếng Việt của thiết bị.',
        );
      }
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _vibration?.cancel();
    if (!widget.arguments.isPreview) {
      ref.read(callProvider.notifier).cancel();
    }
    await ref.read(audioServiceProvider).stop();
  }

  Future<void> _hangUp() async {
    await _stop();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final combo = _combo;
    final theme = CallTheme.of(combo.callInterface);
    final isAnswered = ref.watch(callSessionProvider) == CallStatus.inProgress;
    final caller = ScenarioLookup.resolve(
      combo.scenarioId,
      ref.watch(scenarioLibraryProvider).value,
    ).caller;
    final name = caller.trim().isEmpty ? combo.name.trim() : caller.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
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
          isMuted: _isMuted,
          onToggleMute: () => setState(() => _isMuted = !_isMuted),
          onHangUp: _hangUp,
          // Video hỏng: phát giọng như gọi thoại để cuộc gọi không im lặng.
          onVideoUnavailable: _playConversation,
        ),
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
        onToggleSpeaker: () => setState(() => _isSpeaker = !_isSpeaker),
        onHangUp: _hangUp,
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
        CallInterface.zalo => ZaloIncomingView(
          caller: caller,
          initial: initial,
          theme: theme,
          isVideo: isVideo,
          onAnswer: _answer,
          onDecline: _hangUp,
        ),
        CallInterface.messenger => MessengerIncomingView(
          caller: caller,
          initial: initial,
          theme: theme,
          isVideo: isVideo,
          onAnswer: _answer,
          onDecline: _hangUp,
        ),
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

/// Khung chung của màn gọi: thanh trạng thái trong suốt để nền phủ kín màn
/// hình như app gọi thật, font cuộc gọi, và dừng âm thanh khi vuốt quay lại.
class _CallScaffold extends StatelessWidget {
  const _CallScaffold({
    required this.theme,
    required this.onPop,
    required this.child,
  });
  final CallTheme theme;
  final VoidCallback onPop;
  final Widget child;

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
        systemNavigationBarColor: theme.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.background,
        body: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: CallTheme.fontFamily,
            color: Colors.white,
          ),
          child: child,
        ),
      ),
    ),
  );
}
