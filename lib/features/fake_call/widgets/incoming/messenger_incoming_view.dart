import 'package:flutter/material.dart';

import '../../themes/call_theme.dart';
import '../call_action_button.dart';

/// 7c — Cuộc gọi đến kiểu Messenger: nền tím tối, ba nút Nhắn tin / Từ chối /
/// Trả lời.
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        const SizedBox(height: 16),
        const Spacer(),
        CallAvatar(
          initial: initial,
          color: theme.avatar,
          textColor: theme.avatarText,
          size: 104,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 24),
        Text(
          caller,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          isVideo ? 'đang gọi video cho bạn…' : 'đang gọi thoại cho bạn…',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.subtle, fontSize: 15),
        ),
        const SizedBox(height: 24),
        const Spacer(flex: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Trên Messenger thật, Nhắn tin cũng từ chối cuộc gọi.
            CallButton(
              label: 'Nhắn tin',
              icon: Icons.chat_bubble_outline_rounded,
              color: theme.control,
              size: 64,
              iconSize: 26,
              labelSize: 13,
              labelColor: theme.subtle,
              onTap: onDecline,
            ),
            CallButton(
              label: 'Từ chối',
              icon: Icons.close_rounded,
              color: theme.decline,
              size: 64,
              iconSize: 30,
              labelSize: 13,
              labelColor: theme.subtle,
              onTap: onDecline,
            ),
            CallButton(
              label: 'Trả lời',
              icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: theme.answer,
              size: 64,
              iconSize: 28,
              labelSize: 13,
              labelColor: theme.subtle,
              onTap: onAnswer,
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    ),
  );
}
