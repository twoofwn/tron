import 'package:flutter/material.dart';

import '../../../shared/enums/call_interface.dart';

/// Màu của màn cuộc gọi theo từng giao diện, lấy từ bản thiết kế 7a / 7b / 7c / 8.
class CallTheme {
  const CallTheme._({
    required this.background,
    required this.avatar,
    required this.avatarText,
    required this.answer,
    required this.decline,
    required this.subtle,
    required this.control,
    required this.controlActive,
  });

  final Color background;
  final Color avatar;
  final Color avatarText;
  final Color answer;
  final Color decline;

  /// Chữ phụ: "di động", trạng thái, đồng hồ, nhãn nút nhỏ.
  final Color subtle;

  /// Nền nút phụ (Nhắc tôi, Nhắn tin, lưới nút khi đang gọi).
  final Color control;

  /// Nền nút đang bật (Tắt tiếng, Loa).
  final Color controlActive;

  static const fontFamily = 'BeVietnamPro';

  static CallTheme of(CallInterface callInterface) => switch (callInterface) {
    CallInterface.phone => const CallTheme._(
      background: Color(0xFF20232B),
      avatar: Color(0xFF3A3E4A),
      avatarText: Color(0xFFE6E8EE),
      answer: Color(0xFF2FB463),
      decline: Color(0xFFE5484D),
      subtle: Color(0xFFC7CAD3),
      control: Color(0xFF333743),
      controlActive: Color(0xFFEDEEF2),
    ),
    CallInterface.zalo => const CallTheme._(
      background: Color(0xFF0A5AD6),
      avatar: Colors.white,
      avatarText: Color(0xFF0A5AD6),
      answer: Color(0xFF2CC36B),
      decline: Color(0xFFF0484D),
      subtle: Color(0xFFDCE8FF),
      control: Color(0x2EFFFFFF),
      controlActive: Colors.white,
    ),
    CallInterface.messenger => const CallTheme._(
      background: Color(0xFF17122A),
      avatar: Color(0xFF6D55D9),
      avatarText: Colors.white,
      answer: Color(0xFF2CC36B),
      decline: Color(0xFFF0484D),
      subtle: Color(0xFFCFC8E8),
      control: Color(0xFF2E2748),
      controlActive: Color(0xFFEDEEF2),
    ),
  };
}
