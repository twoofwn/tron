import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/video_recorder.dart';
import '../../../core/services/video_source.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../screens/video_record_screen.dart';

/// Mở màn quay video, trả về `media:...mp4` hoặc `null` nếu người dùng thoát.
typedef VideoRecordLauncher = Future<String?> Function(BuildContext context);

Future<String?> _openRecordScreen(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const VideoRecordScreen(),
      ),
    );

/// Thẻ "Video người gọi" của cuộc gọi video: quay, chọn file, xem lại, quay lại
/// hoặc xoá video tự quay.
class VideoRecorderCard extends ConsumerStatefulWidget {
  const VideoRecorderCard({
    super.key,
    required this.videoPath,
    required this.onChanged,
    required this.onBusyChanged,
    this.launchRecorder = _openRecordScreen,
  });

  /// Video hiện tại (`media:...mp4`), hoặc `null` nếu người gọi tắt camera.
  final String? videoPath;
  final ValueChanged<String?> onChanged;

  /// Báo cho form biết đang quay/nhập video, để khoá nút Lưu và Xem trước.
  final ValueChanged<bool> onBusyChanged;

  /// Cho phép test thay màn quay thật (cần camera).
  final VideoRecordLauncher launchRecorder;

  @override
  ConsumerState<VideoRecorderCard> createState() => _VideoRecorderCardState();
}

class _VideoRecorderCardState extends ConsumerState<VideoRecorderCard> {
  bool _isBusy = false;

  Future<void> _run(Future<String?> Function() action, String error) async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    widget.onBusyChanged(true);
    try {
      // Tắt giọng đọc thử để không lọt vào bản quay.
      await ref.read(scenarioPlaybackProvider.notifier).stop();
      final path = await action();
      if (mounted && path != null) {
        widget.onChanged(path);
      }
    } on FormatException catch (e) {
      if (mounted) {
        showMessage(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _record() => _run(
    () => widget.launchRecorder(context),
    'Không quay được video trên thiết bị này.',
  );

  Future<void> _pick() => _run(() async {
    final path = await ref.read(fileServiceProvider).pickVideo();
    // Chỉ giới hạn dung lượng (kiểm tra khi chọn); ở đây chỉ xem file phát được không.
    return path == null
        ? null
        : ref.read(videoRecorderProvider).checkPickedVideo(path);
  }, 'Không thể nhập video. Chọn file MP4 tối đa 20 MB.');

  Future<void> _watch() async {
    final path = widget.videoPath;
    if (path == null) {
      return;
    }
    await ref.read(scenarioPlaybackProvider.notifier).stop();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _VideoPreviewDialog(path: path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.videoPath != null;
    final canRecord = VideoRecorder.canRecord;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (hasVideo ? AppColors.green : AppColors.purple)
                .withValues(alpha: 0.16),
            child: Icon(
              hasVideo ? Icons.videocam_rounded : Icons.videocam_off_outlined,
              color: hasVideo ? AppColors.green : AppColors.purple,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVideo ? 'Video tự quay' : 'Video người gọi',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasVideo
                      ? 'Bắt máy sẽ phát video này, kèm camera trước của bạn.'
                      : 'Chưa có video: người gọi như đang tắt camera. '
                            'Tối đa 20 MB.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (hasVideo) ...[
            IconButton(
              tooltip: 'Xem lại',
              onPressed: _watch,
              icon: const Icon(
                Icons.play_circle_outline_rounded,
                color: AppColors.accent,
              ),
            ),
            IconButton(
              tooltip: canRecord ? 'Quay lại' : 'Chọn video khác',
              onPressed: canRecord ? _record : _pick,
              icon: Icon(
                canRecord
                    ? Icons.videocam_outlined
                    : Icons.video_library_outlined,
                color: AppColors.muted,
              ),
            ),
            IconButton(
              tooltip: 'Xoá video',
              onPressed: () => widget.onChanged(null),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.muted,
              ),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Chọn video MP4 có sẵn',
              onPressed: _pick,
              icon: const Icon(
                Icons.video_library_outlined,
                color: AppColors.muted,
              ),
            ),
            if (canRecord)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton.tonalIcon(
                  onPressed: _record,
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text('Quay'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Xem lại video tự quay trong form.
class _VideoPreviewDialog extends ConsumerStatefulWidget {
  const _VideoPreviewDialog({required this.path});
  final String path;

  @override
  ConsumerState<_VideoPreviewDialog> createState() =>
      _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends ConsumerState<_VideoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final location = await ref
          .read(fileServiceProvider)
          .videoLocation(widget.path);
      final controller = videoControllerFor(location);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog(
      backgroundColor: Colors.black,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: controller?.value.aspectRatio ?? 9 / 16,
            child: controller != null
                ? GestureDetector(
                    onTap: () => controller.value.isPlaying
                        ? controller.pause()
                        : controller.play(),
                    child: VideoPlayer(controller),
                  )
                : Center(
                    child: _failed
                        ? const Text(
                            'Không phát được video.',
                            style: TextStyle(color: Colors.white70),
                          )
                        : const CircularProgressIndicator(),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
