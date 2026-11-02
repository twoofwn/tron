import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/voice_recorder.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';

/// Thẻ "Giọng người gọi": thu, nghe lại, thu lại hoặc xoá giọng tự thu.
class VoiceRecorderCard extends ConsumerStatefulWidget {
  const VoiceRecorderCard({
    super.key,
    required this.voicePath,
    required this.onChanged,
    required this.onRecordingChanged,
  });

  /// Bản thu hiện tại (`media:...wav`), hoặc `null` nếu dùng giọng máy đọc.
  final String? voicePath;
  final ValueChanged<String?> onChanged;

  /// Báo cho form biết đang thu, để khoá nút Lưu và Xem trước.
  final ValueChanged<bool> onRecordingChanged;

  @override
  ConsumerState<VoiceRecorderCard> createState() => _VoiceRecorderCardState();
}

class _VoiceRecorderCardState extends ConsumerState<VoiceRecorderCard> {
  late final VoiceRecorder _recorder = ref.read(voiceRecorderProvider);
  late final AudioService _audio = ref.read(audioServiceProvider);
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isPlaying = false;

  @override
  void dispose() {
    _ticker?.cancel();
    if (_isRecording) {
      unawaited(_recorder.cancel());
    }
    if (_isPlaying) {
      unawaited(_audio.stop());
    }
    super.dispose();
  }

  void _setRecording(bool value) {
    setState(() => _isRecording = value);
    widget.onRecordingChanged(value);
  }

  Future<void> _start() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      // Tắt mọi âm thanh đang phát để không lọt vào bản thu.
      await ref.read(scenarioPlaybackProvider.notifier).stop();
      await _audio.stop();
      _isPlaying = false;
      if (!await _recorder.start()) {
        if (mounted) {
          showMessage(
            context,
            'Cần quyền micro để thu giọng. Bật lại trong Cài đặt của máy.',
          );
        }
        return;
      }
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      _elapsed = Duration.zero;
      _setRecording(true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed >= VoiceRecorder.maxDuration) {
          _stop(reachedLimit: true);
        }
      });
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không bật được micro trên thiết bị này.');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _stop({bool reachedLimit = false}) async {
    if (!_isRecording) {
      return;
    }
    _ticker?.cancel();
    _setRecording(false);
    setState(() => _isBusy = true);
    try {
      final path = await _recorder.stop();
      if (!mounted) {
        return;
      }
      if (path == null) {
        showMessage(
          context,
          'Bản thu quá ngắn hoặc không có tiếng. Hãy nói ít nhất 1 giây.',
        );
      } else {
        widget.onChanged(path);
        if (reachedLimit) {
          showMessage(
            context,
            'Đã đủ ${durationLabel(VoiceRecorder.maxDuration)} nên bản thu '
            'tự dừng và được lưu.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không lưu được bản thu. Hãy thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    _setRecording(false);
    await _recorder.cancel();
  }

  Future<void> _togglePlay() async {
    final path = widget.voicePath;
    if (path == null) {
      return;
    }
    if (_isPlaying) {
      await _audio.stop();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }
    await ref.read(scenarioPlaybackProvider.notifier).stop();
    setState(() => _isPlaying = true);
    try {
      await _audio.playVoice(path);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không phát được bản thu.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_isPlaying) {
      await _audio.stop();
    }
    if (mounted) {
      setState(() => _isPlaying = false);
      widget.onChanged(null);
    }
  }

  String _format(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasVoice = widget.voicePath != null;
    final (
      IconData icon,
      Color color,
      String title,
      String subtitle,
    ) = _isRecording
        ? (
            Icons.fiber_manual_record_rounded,
            AppColors.red,
            'Đang thu  ${_format(_elapsed)} / ${_format(VoiceRecorder.maxDuration)}',
            VoiceRecorder.maxDuration - _elapsed <= const Duration(seconds: 10)
                ? 'Còn ${(VoiceRecorder.maxDuration - _elapsed).inSeconds} giây, '
                      'hết giờ bản thu tự dừng và được lưu.'
                : 'Nói như người gọi thật, ví dụ “Alo, về nhà ngay con”.',
          )
        : hasVoice
        ? (
            Icons.record_voice_over_rounded,
            AppColors.green,
            'Giọng tự thu',
            'Cuộc gọi sẽ phát giọng này thay cho giọng máy đọc.',
          )
        : (
            Icons.mic_none_rounded,
            AppColors.purple,
            'Giọng người gọi',
            'Đang dùng giọng máy đọc kịch bản. Thu giọng thật cho giống hơn.',
          );
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_isRecording) ...[
            IconButton(
              tooltip: 'Huỷ bản thu',
              onPressed: _cancel,
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
            ),
            IconButton.filled(
              tooltip: 'Dừng và lưu',
              style: IconButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded, color: Colors.white),
            ),
          ] else if (hasVoice) ...[
            IconButton(
              tooltip: _isPlaying ? 'Dừng nghe' : 'Nghe lại',
              onPressed: _isBusy ? null : _togglePlay,
              icon: Icon(
                _isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline_rounded,
                color: AppColors.accent,
              ),
            ),
            IconButton(
              tooltip: 'Thu lại',
              onPressed: _isBusy ? null : _start,
              icon: const Icon(Icons.mic_rounded, color: AppColors.muted),
            ),
            IconButton(
              tooltip: 'Xoá giọng tự thu',
              onPressed: _isBusy ? null : _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.muted,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: FilledButton.tonalIcon(
                onPressed: _isBusy ? null : _start,
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: const Text('Thu giọng'),
              ),
            ),
        ],
      ),
    );
  }
}
