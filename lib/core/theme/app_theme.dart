import 'package:flutter/material.dart';

abstract final class AppColors {
  static const dark = Color(0xFF123A32);
  static const onAccent = Color(0xFF21470F);
  static const onDarkMuted = Color(0xFFA8C5B9);
  static const accent = Color(0xFFBDF56A);
  static const inputPanel = Color(0xFFF8FBF6);
  static const navy = Color(0xFF132B2A);
  static const primary = Color(0xFF2A7552);
  static const primaryPressed = Color(0xFF123A32);
  static const primarySoft = Color(0xFFF0F7EB);
  static const comparison = Color(0xFFF0F7EB);
  static const background = Color(0xFFEEF3F1);
  static const surface = Colors.white;
  static const text = Color(0xFF132B2A);
  static const muted = Color(0xFF6C807D);
  static const border = Color(0xFFDDE8E1);
  static const success = Color(0xFF2A7552);
  static const warning = Color(0xFFAD4C08);
  static const danger = Color(0xFFC12E44);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Cairo',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    surface: AppColors.surface,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    onSurface: AppColors.text,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.text),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputPanel,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    labelStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryPressed,
      minimumSize: const Size(48, 52),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
  dividerTheme: const DividerThemeData(color: AppColors.border, space: 32),
);
