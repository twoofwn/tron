import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  );
  static const section = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );
  static const cardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  static const caption = TextStyle(fontSize: 12, height: 1.5);
}
