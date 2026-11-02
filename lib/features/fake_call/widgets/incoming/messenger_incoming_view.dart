import 'package:flutter/material.dart';

import '../../themes/call_theme.dart';
import '../call_action_button.dart';

/// 7c — Cuộc gọi Messenger đến trên Android: Messenger tự vẽ màn gọi đến cùng
/// kiểu màn đang gọi (nền tối, avatar giữa màn, tên, dòng trạng thái), với hai
/// nút Từ chối / Trả lời ở dưới.
class MessengerIncomingView extends StatelessWidget {
  const MessengerIncomingView({
    super.key,
    required this.caller,
    required this.initial,
    required this.theme,
    required this.onAnswer,
    required this.onDecline,
    this.isVideo = false,
  });
  final String caller;
  final String initial;
  final CallTheme theme;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  /// Cuộc gọi video: đổi dòng trạng thái và biểu tượng nút Trả lời.
  final bool isVideo;

  static const _decline = Color(0xFFFF3B30);
  static const _accept = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      Widget button(double fraction, Widget child) => Positioned(
        left: width * fraction - 50,
        width: 100,
        bottom: 60,
        child: child,
      );
      return Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _MessengerLogo(),
                const SizedBox(width: 8),
                Text(
                  'Messenger',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isVideo
                      ? 'Cuộc gọi video qua Messenger'
                      : 'Cuộc gọi thoại qua Messenger',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          button(
            0.23,
            CallButton(
              label: 'Từ chối',
              icon: Icons.call_end_rounded,
              color: _decline,
              size: 65,
              iconSize: 30,
              labelSize: 14,
              onTap: onDecline,
            ),
          ),
          button(
            0.77,
            CallButton(
              label: 'Trả lời',
              icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: _accept,
              size: 65,
              iconSize: 30,
              labelSize: 14,
              onTap: onAnswer,
            ),
          ),
        ],
      );
    },
  );
}

/// Biểu tượng Messenger: bong bóng chuyển màu xanh – tím – hồng, tia chớp trắng.
class _MessengerLogo extends StatelessWidget {
  const _MessengerLogo();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF0099FF), Color(0xFFA033FF), Color(0xFFFF5C87)],
      ),
    ),
    child: const Icon(Icons.bolt_rounded, size: 15, color: Colors.white),
  );
}
