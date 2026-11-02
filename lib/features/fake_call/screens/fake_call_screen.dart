import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_foreground_provider.dart';
import '../../../core/services/audio_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../activation/services/call_alarm_service.dart';
import '../../combo/models/combo_model.dart';
import '../../scenarios/data/scenario_lookup.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/call_provider.dart';
import '../services/call_device_service.dart';
import '../themes/call_theme.dart';
import '../widgets/in_call_view.dart';
import '../widgets/incoming/messenger_incoming_view.dart';
import '../widgets/incoming/phone_incoming_view.dart';
import '../widgets/incoming/zalo_incoming_view.dart';

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
  StreamSubscription<void>? _volumeKeys;

  ComboModel get _combo => widget.arguments.combo;
  ScenarioInfo get _scenario => ScenarioLookup.resolve(
    _combo.scenarioId,
    ref.read(scenarioLibraryProvider).value,
  );
  String get _dialogue => _scenario.dialogue;

  @override
  void initState() {
    super.initState();
    _device = ref.read(callDeviceServiceProvider);
    _volumeKeys = _device.volumeKeyPresses.listen((_) => _silenceRinging());
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vibration?.cancel();
    unawaited(_volumeKeys?.cancel());
    unawaited(_device.setSilenceKeys(false));
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
            .prepareSpeech(_dialogue)
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
    await _playConversation();
  }

  Future<void> _playConversation() async {
    try {
      await ref.read(audioServiceProvider).conversation(_combo, _dialogue);
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
    await _device.setSilenceKeys(false);
    if (_answeredAt != null) {
      await _device.endCallAudio();
    }
  }

  Future<void> _hangUp() async {
    await _stop();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appForegroundProvider, _onForegroundChanged);
    final combo = _combo;
    final theme = CallTheme.of(combo.callInterface);
    final isAnswered = ref.watch(callSessionProvider) == CallStatus.inProgress;
    final caller = ScenarioLookup.resolve(
      combo.scenarioId,
      ref.watch(scenarioLibraryProvider).value,
    ).caller;
    final name = caller.trim().isEmpty ? combo.name.trim() : caller.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
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
      );
    } else {
      view = switch (combo.callInterface) {
        CallInterface.phone => PhoneIncomingView(
          caller: caller,
          initial: initial,
          theme: theme,
          onAnswer: _answer,
          onDecline: _hangUp,
        ),
        CallInterface.zalo => ZaloIncomingView(
          caller: caller,
          initial: initial,
          theme: theme,
          onAnswer: _answer,
          onDecline: _hangUp,
        ),
        CallInterface.messenger => MessengerIncomingView(
          caller: caller,
          initial: initial,
          theme: theme,
          onAnswer: _answer,
          onDecline: _hangUp,
        ),
      };
    }
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _stop();
        }
      },
      // Thanh trạng thái trong suốt để nền phủ kín màn hình như app gọi thật.
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
                            builder: (context, constraints) =>
                                SingleChildScrollView(
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
          ),
        ),
      ),
    );
  }
}
