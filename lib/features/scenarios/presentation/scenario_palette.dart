import 'package:flutter/material.dart';

class ScenarioPalette {
  static const background = Color(0xFF101115);
  static const card = Color(0xFF1B1D23);
  static const outline = Color(0xFF2D303A);
  static const muted = Color(0xFF9A9BA8);
  static const yellow = Color(0xFFF6B83F);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: yellow,
      onPrimary: Color(0xFF14110A),
      surface: card,
      onSurface: Color(0xFFF3F3F6),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: yellow,
        foregroundColor: const Color(0xFF17130B),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
  );

  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
    color: selected ? const Color(0xFF29241B) : card,
    border: Border.all(
      color: selected ? yellow : outline,
      width: selected ? 1.5 : 1,
    ),
    borderRadius: BorderRadius.circular(19),
  );
}
