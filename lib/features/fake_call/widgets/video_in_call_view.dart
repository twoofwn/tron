import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/file_service.dart';
import '../../../core/services/video_recorder.dart';
import '../../../core/services/video_source.dart';
import '../themes/call_theme.dart';
import 'call_action_button.dart';

/// 8b — Màn đang gọi video: video người gọi phủ kín màn hình, khung nhỏ góc trên
/// là camera trước của người dùng (chỉ xem, không quay, không thu tiếng).
/// Không có video thì hiện như người gọi tắt camera; video lỗi thì báo thêm
/// [onVideoUnavailable] để màn gọi phát giọng thay thế.
class VideoInCallView extends ConsumerStatefulWidget {
  const VideoInCallView({
    super.key,
    required this.caller,
    required this.initial,
    required this.theme,
    required this.elapsed,
    required this.videoPath,
    required this.isMuted,
    required this.onToggleMute,
    required this.onHangUp,
    required this.onVideoUnavailable,
  });
  final String caller;
  final String initial;
  final CallTheme theme;
  final Duration elapsed;

  /// Video người gọi (`media:...mp4`), `null` nếu combo chưa có video.
  final String? videoPath;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onHangUp;
  final VoidCallback onVideoUnavailable;

  @override
  ConsumerState<VideoInCallView> createState() => _VideoInCallViewState();
}

class _VideoInCallViewState extends ConsumerState<VideoInCallView>
    with WidgetsBindingObserver {
  late final VideoRecorder _recorder = ref.read(videoRecorderProvider);
  VideoPlayerController? _remote;
  bool _remoteUnavailable = false;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _camera;
  CameraController? _self;
  bool _selfFailed = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openRemote();
    _openSelf();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_remote?.dispose());
    unawaited(_self?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Trả camera cho hệ thống khi app ra nền, mở lại khi quay về.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _closeSelf();
    } else if (state == AppLifecycleState.resumed &&
        _self == null &&
        !_cameraOff) {
      _openSelf();
    }
  }

  Future<void> _openRemote() async {
    final path = widget.videoPath;
    // Combo chưa có video: màn gọi đã phát giọng từ đầu, chỉ cần hiện avatar.
    if (path == null) {
      _remoteUnavailable = true;
      return;
    }
    VideoPlayerController? controller;
    try {
      final location = await ref.read(fileServiceProvider).videoLocation(path);
      controller = videoControllerFor(location);
      await controller.initialize();
      // Hết video thì dừng ở khung cuối, như người gọi ngừng nói.
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _remote = controller);
      await controller.play();
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        setState(() => _remote = null);
      }
      _markRemoteUnavailable();
    }
  }

  void _markRemoteUnavailable() {
    if (!mounted || _remoteUnavailable) {
      return;
    }
    setState(() => _remoteUnavailable = true);
    widget.onVideoUnavailable();
  }

  Future<void> _openSelf() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await _recorder.cameras();
      }
      final camera = _camera ?? VideoRecorder.preferFront(_cameras);
      if (camera == null) {
        throw StateError('Không có camera.');
      }
      final controller = _recorder.previewController(camera);
      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
      if (!mounted || _cameraOff) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _self = controller;
        _selfFailed = false;
      });
    } catch (_) {
      // Không có quyền camera hoặc máy không có camera: khung nhỏ hiện màu tối.
      if (mounted) {
        setState(() => _selfFailed = true);
      }
    }
  }

  void _closeSelf() {
    final controller = _self;
    if (controller == null) {
      return;
    }
    setState(() => _self = null);
    unawaited(controller.dispose());
  }

  void _toggleCamera() {
    setState(() => _cameraOff = !_cameraOff);
    if (_cameraOff) {
      _closeSelf();
    } else {
      _openSelf();
    }
  }

  Future<void> _flip() async {
    final current = _camera;
    if (_cameras.length < 2 || current == null) {
      return;
    }
    _camera = _cameras[(_cameras.indexOf(current) + 1) % _cameras.length];
    _closeSelf();
    if (!_cameraOff) {
      await _openSelf();
    }
  }

  String get _time =>
      '${widget.elapsed.inMinutes.toString().padLeft(2, '0')}:${(widget.elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final remote = _remote;
    Widget control(
      IconData icon,
      String label, {
      bool active = false,
      VoidCallback? onTap,
    }) => Expanded(
      child: CallButton(
        label: label,
        icon: icon,
        color: active ? theme.controlActive : Colors.white24,
        iconColor: active ? theme.background : Colors.white,
        size: 56,
        iconSize: 24,
        labelSize: 12,
        toggled: onTap == null ? null : active,
        onTap: onTap,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video người gọi, hoặc avatar khi người gọi "tắt camera".
        if (remote != null && remote.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: remote.value.size.width,
              height: remote.value.size.height,
              child: VideoPlayer(remote),
            ),
          )
        else
          ColoredBox(
            color: theme.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CallAvatar(
                    initial: widget.initial,
                    color: theme.avatar,
                    textColor: theme.avatarText,
                    size: 112,
                    fontSize: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _remoteUnavailable ? 'Camera đang tắt' : 'Đang kết nối…',
                    style: TextStyle(color: theme.subtle, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        // Lớp tối trên/dưới để chữ và nút luôn đọc được trên nền video.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xB3000000),
              ],
              stops: [0, 0.25, 0.65, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 24),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.caller,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _time,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SelfView(
                      controller: _self,
                      isOff: _cameraOff || _selfFailed,
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    control(
                      Icons.flip_camera_ios_rounded,
                      'đổi camera',
                      onTap: _cameras.length < 2 || _cameraOff ? null : _flip,
                    ),
                    control(
                      Icons.videocam_off_rounded,
                      'tắt camera',
                      active: _cameraOff,
                      onTap: _toggleCamera,
                    ),
                    control(
                      Icons.mic_off_rounded,
                      'tắt tiếng',
                      active: widget.isMuted,
                      onTap: widget.onToggleMute,
                    ),
                    Expanded(
                      child: CallButton(
                        label: 'Kết thúc',
                        icon: Icons.call_end_rounded,
                        color: theme.decline,
                        size: 56,
                        iconSize: 26,
                        labelSize: 12,
                        onTap: widget.onHangUp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Khung nhỏ hiện camera trước của người dùng.
class _SelfView extends StatelessWidget {
  const _SelfView({required this.controller, required this.isOff});
  final CameraController? controller;
  final bool isOff;

  static const _width = 104.0;
  static const _height = 152.0;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final ready =
        !isOff && controller != null && controller.value.isInitialized;
    return Semantics(
      label: ready ? 'Camera của bạn' : 'Camera của bạn đang tắt',
      child: Container(
        width: _width,
        height: _height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: ready
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                // Ở màn dọc, khung xem trước cao gấp `aspectRatio` lần bề ngang.
                child: SizedBox(
                  width: _width,
                  height: _width * controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              )
            : const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white54,
                size: 28,
              ),
      ),
    );
  }
}
