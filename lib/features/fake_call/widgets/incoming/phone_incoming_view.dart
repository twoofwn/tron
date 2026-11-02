import 'package:flutter/material.dart';

import '../../themes/call_theme.dart';
import '../call_action_button.dart';

/// 7a — Cuộc gọi đến kiểu điện thoại gốc: tên chữ mảnh, avatar dưới tên,
/// hàng Nhắc tôi / Tin nhắn và hai nút Từ chối / Trả lời.
class PhoneIncomingView extends StatelessWidget {
  const PhoneIncomingView({
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      children: [
        const SizedBox(height: 16),
        const Spacer(),
        Text(
          isVideo ? 'cuộc gọi video' : 'di động',
          style: TextStyle(color: theme.subtle, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          caller,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 40),
        CallAvatar(
          initial: initial,
          color: theme.avatar,
          textColor: theme.avatarText,
          size: 120,
          fontSize: 46,
        ),
        const SizedBox(height: 24),
        const Spacer(flex: 4),
        // Trên máy thật, hai nút này đều từ chối cuộc gọi.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CallButton(
              label: 'Nhắc tôi',
              icon: Icons.schedule_rounded,
              color: theme.control,
              size: 52,
              iconSize: 22,
              labelSize: 13,
              labelColor: theme.subtle,
              onTap: onDecline,
            ),
            CallButton(
              label: 'Tin nhắn',
              icon: Icons.chat_bubble_outline_rounded,
              color: theme.control,
              size: 52,
              iconSize: 22,
              labelSize: 13,
              labelColor: theme.subtle,
              onTap: onDecline,
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CallButton(
              label: 'Từ chối',
              icon: Icons.call_end_rounded,
              color: theme.decline,
              onTap: onDecline,
            ),
            CallButton(
              label: 'Trả lời',
              icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: theme.answer,
              onTap: onAnswer,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    ),
  );
}
