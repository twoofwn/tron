import 'package:flutter/material.dart';

import 'call_action_button.dart';

/// Màn đang gọi thoại của Messenger trên iPhone: nền tối mờ, nút thu nhỏ và
/// thêm người ở trên, avatar giữa màn, tên + đồng hồ, thanh điều khiển bo tròn
/// ở dưới (video, mic, loa, nút đỏ kết thúc) không có chữ.
class MessengerInCallView extends StatelessWidget {
  const MessengerInCallView({
    super.key,
    required this.caller,
    required this.initial,
    required this.elapsed,
    required this.isMuted,
    required this.isSpeaker,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onHangUp,
    this.onSos,
    this.statusHint,
    this.endedLabel,
  });
  final String caller;
  final String initial;
  final Duration elapsed;
  final bool isMuted;
  final bool isSpeaker;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  /// Giữ nút kết thúc 2 giây: gửi SOS (không có chữ nào gợi ý).
  final VoidCallback? onSos;
  final Widget? statusHint;

  /// Khác `null` khi cuộc gọi vừa kết thúc: dòng này thay đồng hồ, các nút mờ
  /// đi trong giây lát trước khi màn gọi đóng, như máy thật.
  final String? endedLabel;

  static const background = Color(0xFF1B1726);
  static const _control = Color(0xFF3A3A3C);
  static const _end = Color(0xFFFF3B30);

  String get _time =>
      '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        left: 16,
        top: 4,
        child: _TopIcon(Icons.keyboard_arrow_down_rounded),
      ),
      const Positioned(
        right: 16,
        top: 4,
        child: _TopIcon(Icons.person_add_alt_1_rounded),
      ),
      Positioned(
        left: 24,
        right: 24,
        top: 120,
        child: Column(
          children: [
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF6D55D9),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              caller,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              endedLabel ?? _time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (statusHint != null && endedLabel == null) ...[
              const SizedBox(height: 8),
              statusHint!,
            ],
          ],
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 20,
        child: CallEndFade(
          ended: endedLabel != null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const _Control(label: 'Video', icon: Icons.videocam_rounded),
                _Control(
                  label: 'Tắt tiếng',
                  icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  active: isMuted,
                  onTap: onToggleMute,
                ),
                _Control(
                  label: 'Loa',
                  icon: Icons.volume_up_rounded,
                  active: isSpeaker,
                  onTap: onToggleSpeaker,
                ),
                CallButton(
                  label: 'Kết thúc',
                  icon: Icons.call_end_rounded,
                  color: _end,
                  size: 52,
                  iconSize: 26,
                  showLabel: false,
                  onTap: onHangUp,
                  onHold: onSos,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _TopIcon extends StatelessWidget {
  const _TopIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 26, color: Colors.white),
  );
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.icon,
    this.active = false,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CallButton(
    label: label,
    icon: icon,
    color: active ? Colors.white : MessengerInCallView._control,
    iconColor: active ? Colors.black : Colors.white,
    size: 52,
    iconSize: 26,
    showLabel: false,
    toggled: onTap == null ? null : active,
    onTap: onTap,
  );
}
