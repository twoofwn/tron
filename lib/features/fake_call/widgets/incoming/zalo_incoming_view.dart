import 'package:flutter/material.dart';

import '../../themes/call_theme.dart';
import '../call_action_button.dart';
import '../zalo_in_call_view.dart';

/// 7b — Cuộc gọi Zalo đến trên Android: Zalo tự vẽ màn gọi đến, cùng kiểu với
/// màn đang gọi (nền xanh, "Zalo" + HD, avatar viền xanh, tên), thay đồng hồ
/// bằng dòng trạng thái và hai nút Từ chối / Trả lời.
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

  static const _decline = Color(0xFFF2655E);
  static const _accept = Color(0xFF2DC76D);

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
          Positioned.fill(
            child: ZaloCallHeader(
              caller: caller,
              status: Text(
                isVideo ? 'Cuộc gọi video đến' : 'Cuộc gọi thoại đến',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
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
