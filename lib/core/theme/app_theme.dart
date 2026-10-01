import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryPressed = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFDBEAFE);
  static const comparison = Color(0xFFEFF6FF);
  static const background = Color(0xFFF7FAFC);
  static const surface = Colors.white;
  static const text = Color(0xFF172033);
  static const muted = Color(0xFF617086);
  static const border = Color(0xFFDEE6F0);
  static const success = Color(0xFF168A68);
  static const warning = Color(0xFFD58A16);
  static const danger = Color(0xFFC84343);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Cairo',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    surface: AppColors.surface,
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
      foregroundColor: AppColors.muted,
      minimumSize: const Size(48, 52),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.border, space: 32),
);
