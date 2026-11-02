import 'package:flutter/material.dart';

import '../themes/call_theme.dart';
import 'call_action_button.dart';

/// 8 — Màn đang gọi: tên, đồng hồ, lưới 6 nút và nút Kết thúc. Tắt tiếng và Loa
/// đổi trạng thái như máy thật; các nút còn lại chỉ để trông giống màn gọi.
class InCallView extends StatelessWidget {
  const InCallView({
    super.key,
    required this.caller,
    required this.theme,
    required this.elapsed,
    required this.isMuted,
    required this.isSpeaker,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onHangUp,
    this.onSos,
    this.statusHint,
  });
  final String caller;
  final CallTheme theme;
  final Duration elapsed;
  final bool isMuted;
  final bool isSpeaker;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  /// Giữ nút gác máy 2 giây: gửi SOS (không có chữ nào trên màn hình gợi ý).
  final VoidCallback? onSos;

  /// Dòng nhỏ dưới đồng hồ, chỉ dùng ở bản xem thử (ví dụ "Đang nghe bạn…").
  final Widget? statusHint;

  String get _time =>
      '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    Widget control(
      IconData icon,
      String label, {
      bool active = false,
      VoidCallback? onTap,
    }) => Expanded(
      child: CallButton(
        label: label,
        icon: icon,
        color: active ? theme.controlActive : theme.control,
        iconColor: active ? theme.background : Colors.white,
        size: 72,
        iconSize: 26,
        labelSize: 13,
        toggled: onTap == null ? null : active,
        onTap: onTap,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Spacer(),
          Text(
            caller,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _time,
            style: TextStyle(
              color: theme.subtle,
              fontSize: 17,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (statusHint != null) ...[const SizedBox(height: 8), statusHint!],
          const SizedBox(height: 24),
          const Spacer(flex: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              control(
                Icons.mic_off_rounded,
                'tắt tiếng',
                active: isMuted,
                onTap: onToggleMute,
              ),
              control(Icons.dialpad_rounded, 'bàn phím'),
              control(
                Icons.volume_up_rounded,
                'loa',
                active: isSpeaker,
                onTap: onToggleSpeaker,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              control(Icons.add_rounded, 'thêm'),
              control(Icons.videocam_outlined, 'video'),
              control(Icons.person_outline_rounded, 'danh bạ'),
            ],
          ),
          const SizedBox(height: 48),
          CallButton(
            label: 'Kết thúc',
            icon: Icons.call_end_rounded,
            color: theme.decline,
            showLabel: false,
            onTap: onHangUp,
            onHold: onSos,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
