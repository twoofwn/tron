import 'package:flutter/material.dart';

import '../../themes/call_theme.dart';
import '../call_action_button.dart';

/// 7b — Cuộc gọi đến kiểu Zalo: nền xanh, avatar trắng có vòng sáng nhấp nháy,
/// hai nút Từ chối / Trả lời.
class ZaloIncomingView extends StatelessWidget {
  const ZaloIncomingView({
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Chừa chỗ cho vòng sáng quanh avatar.
      const SizedBox(height: 32),
      const Spacer(),
      _PulsingHalo(
        child: CallAvatar(
          initial: initial,
          color: theme.avatar,
          textColor: theme.avatarText,
          size: 116,
          fontSize: 44,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 40),
      Text(
        caller,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        isVideo ? 'Cuộc gọi video đến…' : 'Cuộc gọi thoại đến…',
        style: TextStyle(color: theme.subtle, fontSize: 15),
      ),
      const SizedBox(height: 40),
      const Spacer(flex: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          CallButton(
            label: 'Từ chối',
            icon: Icons.call_end_rounded,
            color: theme.decline,
            size: 68,
            iconSize: 28,
            onTap: onDecline,
          ),
          CallButton(
            label: 'Trả lời',
            icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            color: theme.answer,
            size: 68,
            iconSize: 28,
            onTap: onAnswer,
          ),
        ],
      ),
      const SizedBox(height: 48),
    ],
  );
}

/// Hai vòng sáng quanh avatar, phình ra thu vào như lúc Zalo đổ chuông.
class _PulsingHalo extends StatefulWidget {
  const _PulsingHalo({required this.child});
  final Widget child;
  @override
  State<_PulsingHalo> createState() => _PulsingHaloState();
}

class _PulsingHaloState extends State<_PulsingHalo>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tắt nhấp nháy khi người dùng bật giảm chuyển động.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(_controller.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.14),
              spreadRadius: 8 + 4 * t,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.07),
              spreadRadius: 18 + 8 * t,
            ),
          ],
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}
