import 'package:flutter/material.dart';

class DykColors {
  static const yellow = Color(0xFFFFC107);
  static const black = Color(0xFF1A1A1A);
  static const cream = Color(0xFFFAF6EE);
  static const green = Color(0xFF22C55E);
}

ThemeData dykLightTheme() => _base(Brightness.light);
ThemeData dykDarkTheme() => _base(Brightness.dark);

ThemeData _base(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: dark ? DykColors.black : DykColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DykColors.yellow,
      brightness: b,
      primary: DykColors.yellow,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DykColors.yellow,
        foregroundColor: DykColors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );
}
