import 'package:flutter/material.dart';

abstract final class AppColors {
  static const accent = Color(0xFFF97316);
  static const inputPanel = Color(0xFFF4F6FC);
  static const navy = Color(0xFF0D1733);
  static const primary = Color(0xFF2357F5);
  static const primaryPressed = Color(0xFF173AB8);
  static const primarySoft = Color(0xFFE6EDFF);
  static const comparison = Color(0xFFEEF2FF);
  static const background = Color(0xFFF0F3FA);
  static const surface = Colors.white;
  static const text = Color(0xFF0D1733);
  static const muted = Color(0xFF465775);
  static const border = Color(0xFFD9E1F0);
  static const success = Color(0xFF087C5A);
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
    fillColor: AppColors.surface,
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
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
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
