import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/audio_service.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../combo/models/combo_model.dart';
import '../../scenario/repositories/scenario_repository.dart';
import '../providers/call_provider.dart';

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
  DateTime? _answeredAt;
  Duration _elapsed = Duration.zero;
  bool _isMuted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRinging() async {
    try {
      await ref.read(audioServiceProvider).ring(widget.arguments.combo);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không phát được chuông trên thiết bị này.');
      }
    }
  }

  Future<void> _answer() async {
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
    try {
      await ref
          .read(audioServiceProvider)
          .conversation(
            widget.arguments.combo,
            ScenarioRepository.find(widget.arguments.combo.scenarioId).dialogue,
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

  Future<void> _stop() async {
    _timer?.cancel();
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
    final combo = widget.arguments.combo;
    final isAnswered = ref.watch(callSessionProvider) == CallStatus.inProgress;
    final background = switch (combo.callInterface) {
      CallInterface.phone => const Color(0xFF171D23),
      CallInterface.zalo => const Color(0xFF0A4B9D),
      CallInterface.messenger => const Color(0xFF23143C),
    };
    final caller = ScenarioRepository.find(combo.scenarioId).caller;
    final time =
        '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _stop();
        }
      },
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    if (widget.arguments.isPreview)
                      const Text(
                        'XEM TRƯỚC CUỘC GỌI',
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 2,
                          fontSize: 10,
                        ),
                      ),
                    const SizedBox(height: 28),
                    Text(
                      combo.callInterface.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white12,
                      child: Text(
                        combo.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 44,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      caller,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isAnswered ? time : 'Cuộc gọi đến…',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (isAnswered) ...[
                      IconButton.filledTonal(
                        onPressed: () async {
                          setState(() => _isMuted = !_isMuted);
                          if (_isMuted) {
                            await ref.read(audioServiceProvider).stop();
                          } else {
                            try {
                              await ref
                                  .read(audioServiceProvider)
                                  .conversation(
                                    combo,
                                    ScenarioRepository.find(combo.scenarioId)
                                        .dialogue,
                                  );
                            } catch (_) {
                              if (context.mounted) {
                                showMessage(
                                  context,
                                  'Không phát được âm thanh.',
                                );
                              }
                            }
                          }
                        },
                        icon: Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                        tooltip: _isMuted ? 'Bật âm thanh' : 'Tắt âm thanh',
                      ),
                      const SizedBox(height: 30),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallAction(
                          label: isAnswered ? 'Kết thúc' : 'Từ chối',
                          color: AppColors.red,
                          icon: Icons.call_end_rounded,
                          onTap: _hangUp,
                        ),
                        if (!isAnswered)
                          _CallAction(
                            label: 'Trả lời',
                            color: AppColors.green,
                            icon: Icons.call_rounded,
                            onTap: _answer,
                          ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
