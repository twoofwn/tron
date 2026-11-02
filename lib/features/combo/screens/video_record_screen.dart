import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/video_recorder.dart';
import '../../../shared/widgets/screen_shell.dart';

/// Màn quay video người gọi cho cuộc gọi video. Quay xong trả về đường dẫn
/// `media:...mp4` qua `Navigator.pop`; thoát giữa chừng thì không lưu gì.
class VideoRecordScreen extends ConsumerStatefulWidget {
  const VideoRecordScreen({super.key});

  @override
  ConsumerState<VideoRecordScreen> createState() => _VideoRecordScreenState();
}

class _VideoRecordScreenState extends ConsumerState<VideoRecordScreen>
    with WidgetsBindingObserver {
  late final VideoRecorder _recorder = ref.read(videoRecorderProvider);
  List<CameraDescription> _cameras = const [];
  CameraDescription? _camera;
  CameraController? _controller;
  String? _error;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Camera bị hệ thống thu hồi khi app ra nền: bỏ bản đang quay, mở lại khi quay về.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _release();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      final camera = _camera;
      if (camera != null) {
        _open(camera);
      }
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await _recorder.cameras();
    } catch (_) {
      _cameras = const [];
    }
    final camera = VideoRecorder.preferFront(_cameras);
    if (camera == null) {
      if (mounted) {
        setState(() => _error = 'Không tìm thấy camera trên thiết bị này.');
      }
      return;
    }
    await _open(camera);
  }

  Future<void> _open(CameraDescription camera) async {
    final old = _controller;
    final controller = _recorder.recordingController(camera);
    setState(() {
      _camera = camera;
      _controller = null;
      _error = null;
    });
    await old?.dispose();
    try {
      await controller.initialize();
      // Khoá hướng quay theo màn hình hiện tại (dọc) như cuộc gọi video.
      await controller.lockCaptureOrientation();
    } on CameraException catch (error) {
      await controller.dispose();
      if (mounted) {
        setState(() => _error = _describe(error));
      }
      return;
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _error = 'Không mở được camera trên thiết bị này.');
      }
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  String _describe(CameraException error) => switch (error.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' =>
      'Cần quyền camera để quay video. Bật lại trong Cài đặt của máy.',
    'AudioAccessDenied' ||
    'AudioAccessDeniedWithoutPrompt' ||
    'AudioAccessRestricted' =>
      'Cần quyền micro để quay video có tiếng. Bật lại trong Cài đặt của máy.',
    _ => 'Không mở được camera trên thiết bị này.',
  };

  void _release() {
    _ticker?.cancel();
    final controller = _controller;
    if (controller == null) {
      return;
    }
    setState(() {
      _controller = null;
      _isRecording = false;
    });
    unawaited(controller.dispose());
  }

  Future<void> _record() async {
    final controller = _controller;
    if (controller == null || _isRecording || _isSaving) {
      return;
    }
    try {
      await controller.startVideoRecording();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không bắt đầu quay được. Hãy thử lại.');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= VideoRecorder.maxDuration) {
        _stop();
      }
    });
  }

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null || !_isRecording) {
      return;
    }
    _ticker?.cancel();
    setState(() {
      _isRecording = false;
      _isSaving = true;
    });
    try {
      final file = await controller.stopVideoRecording();
      if (_elapsed < VideoRecorder.minDuration) {
        await _recorder.discard(file);
        if (mounted) {
          showMessage(context, 'Video quá ngắn. Giữ quay ít nhất 1 giây.');
        }
        return;
      }
      final path = await _recorder.save(file);
      if (!mounted) {
        return;
      }
      if (path == null) {
        showMessage(context, 'Bản quay trống. Hãy thử lại.');
        return;
      }
      Navigator.pop(context, path);
    } on FormatException catch (error) {
      if (mounted) {
        showMessage(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không lưu được video. Hãy thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _flip() {
    final current = _camera;
    if (_cameras.length < 2 || current == null || _isRecording) {
      return;
    }
    final next = _cameras[(_cameras.indexOf(current) + 1) % _cameras.length];
    _open(next);
  }

  String _format(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      // Đang lưu thì chờ xong, tránh mất bản vừa quay.
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(child: CameraPreview(controller))
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        _TimerPill(
                          label:
                              '${_format(_elapsed)} / ${_format(VideoRecorder.maxDuration)}',
                          isRecording: _isRecording,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!_isRecording && !_isSaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Quay người gọi nói như đang gọi video cho bạn. '
                        'Video sẽ phát khi bạn bắt máy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 48),
                        _RecordButton(
                          isRecording: _isRecording,
                          isBusy: _isSaving,
                          onPressed: controller == null
                              ? null
                              : _isRecording
                              ? _stop
                              : _record,
                        ),
                        IconButton(
                          tooltip: 'Đổi camera',
                          iconSize: 30,
                          onPressed:
                              _cameras.length < 2 || _isRecording || _isSaving
                              ? null
                              : _flip,
                          icon: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.label, required this.isRecording});
  final String label;
  final bool isRecording;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isRecording ? AppColors.red : Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isRecording,
    required this.isBusy,
    required this.onPressed,
  });
  final bool isRecording;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: isRecording ? 'Dừng và lưu video' : 'Bắt đầu quay',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: isBusy ? null : onPressed,
      child: Container(
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: isBusy
            ? const CircularProgressIndicator(color: Colors.white)
            : AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.all(isRecording ? 14 : 0),
                decoration: BoxDecoration(
                  color: onPressed == null ? Colors.white24 : AppColors.red,
                  borderRadius: BorderRadius.circular(isRecording ? 6 : 40),
                ),
              ),
      ),
    ),
  );
}
