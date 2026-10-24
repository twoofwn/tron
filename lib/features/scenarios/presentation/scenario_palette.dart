import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/scenario.dart';

/// Bảng màu của kho kịch bản, có một bộ cho nền tối và một bộ cho nền sáng.
/// Widget lấy màu qua `ScenarioPalette.of(context)` để tự đổi theo chế độ
/// sáng / tối của app thay vì dùng màu cố định.
@immutable
class ScenarioPalette {
  const ScenarioPalette._({
    required this.background,
    required this.card,
    required this.selectedCard,
    required this.outline,
    required this.text,
    required this.muted,
    required this.yellow,
    required this.yellowText,
    required this.onYellow,
    required this.stepBadge,
    required this.chipSelected,
    required this.onChipSelected,
    required this.familyAvatar,
    required this.familyLetter,
    required this.workAvatar,
    required this.workLetter,
    required this.personalAvatar,
    required this.personalLetter,
  });

  /// Nền màn hình và bottom sheet.
  final Color background;

  /// Nền thẻ thường và thẻ đang chọn.
  final Color card;
  final Color selectedCard;
  final Color outline;

  /// Chữ chính và chữ phụ.
  final Color text;
  final Color muted;

  /// Vàng dùng làm nền (nút, nhãn "Đang chọn").
  final Color yellow;

  /// Vàng dùng cho chữ / icon. Trên nền sáng cần đậm hơn để đủ tương phản.
  final Color yellowText;

  /// Chữ đặt trên nền vàng.
  final Color onYellow;

  /// Nền số thứ tự câu thoại trong timeline.
  final Color stepBadge;

  /// Chip bộ lọc đang chọn.
  final Color chipSelected;
  final Color onChipSelected;

  final Color familyAvatar;
  final Color familyLetter;
  final Color workAvatar;
  final Color workLetter;
  final Color personalAvatar;
  final Color personalLetter;

  static const dark = ScenarioPalette._(
    background: AppColors.background,
    card: AppColors.surface,
    selectedCard: Color(0xFF29241B),
    outline: AppColors.border,
    text: Color(0xFFF3F3F6),
    muted: AppColors.muted,
    yellow: AppColors.accent,
    yellowText: AppColors.accent,
    onYellow: Color(0xFF17130B),
    stepBadge: Color(0xFF3A301C),
    chipSelected: Color(0xFFF1F2F6),
    onChipSelected: AppColors.background,
    familyAvatar: Color(0xFF362B18),
    familyLetter: AppColors.accent,
    workAvatar: Color(0xFF1C283D),
    workLetter: Color(0xFF8EB6F8),
    personalAvatar: Color(0xFF32213B),
    personalLetter: Color(0xFFD6A4E7),
  );

  // Nền, thẻ và viền khớp với AppTheme.create(Brightness.light).
  static const light = ScenarioPalette._(
    background: Color(0xFFF4F5F8),
    card: Color(0xFFFFFFFF),
    selectedCard: Color(0xFFFFF6E0),
    outline: Color(0xFFE3E4E9),
    text: Color(0xFF16181D),
    muted: Color(0xFF6B7180),
    yellow: AppColors.accent,
    yellowText: Color(0xFF9A6700),
    onYellow: Color(0xFF17130B),
    stepBadge: Color(0xFFFFEDC2),
    chipSelected: Color(0xFF16181D),
    onChipSelected: Color(0xFFFFFFFF),
    familyAvatar: Color(0xFFFFEDC2),
    familyLetter: Color(0xFF9A6700),
    workAvatar: Color(0xFFE1EBFD),
    workLetter: Color(0xFF2F5FB3),
    personalAvatar: Color(0xFFF2E4F8),
    personalLetter: Color(0xFF85469E),
  );

  static ScenarioPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Giữ theme hiện tại của app (sáng hoặc tối), chỉ chỉnh cỡ chữ và nút
  /// chính cho riêng kho kịch bản.
  static ThemeData themeFrom(ThemeData base) {
    final palette = base.brightness == Brightness.dark ? dark : light;
    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: base.textTheme.merge(
        const TextTheme(
          displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.yellow,
          foregroundColor: palette.onYellow,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      // Nút viền mặc định dùng màu vàng nhạt, khó đọc trên nền sáng.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.yellowText,
          side: BorderSide(color: palette.outline),
        ),
      ),
    );
  }

  /// Màu avatar và chữ cái đầu của thẻ kịch bản theo nhóm.
  (Color background, Color letter) category(ScenarioCategory category) =>
      switch (category) {
        ScenarioCategory.family => (familyAvatar, familyLetter),
        ScenarioCategory.work => (workAvatar, workLetter),
        ScenarioCategory.personal => (personalAvatar, personalLetter),
      };

  BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
    color: selected ? selectedCard : card,
    border: Border.all(
      color: selected ? yellow : outline,
      width: selected ? 1.5 : 1,
    ),
    borderRadius: BorderRadius.circular(19),
  );
}

/// Áp theme kho kịch bản lên theme hiện tại. Dùng cho mọi route của kho
/// (danh sách, chi tiết) vì route mới không kế thừa `Theme` bọc ở route cũ.
class ScenarioTheme extends StatelessWidget {
  const ScenarioTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: ScenarioPalette.themeFrom(Theme.of(context)), child: child);
}
