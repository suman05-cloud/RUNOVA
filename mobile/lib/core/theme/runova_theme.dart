import 'package:flutter/material.dart';

abstract final class RunovaColors {
  static const background = Color(0xFF07110C);
  static const surface = Color(0xFF0F1E16);
  static const elevatedSurface = Color(0xFF172A1E);
  static const primary = Color(0xFF43E47D);
  static const primaryDark = Color(0xFF0BAE55);
  static const textMuted = Color(0xFF95A89C);
  static const warning = Color(0xFFFFC857);
  static const danger = Color(0xFFFF6B6B);
  static const enemy = Color(0xFFFF775F);
}

abstract final class RunovaTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RunovaColors.primary,
      brightness: Brightness.dark,
      surface: RunovaColors.surface,
      error: RunovaColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RunovaColors.background,
      cardTheme: const CardThemeData(
        color: RunovaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RunovaColors.surface,
        indicatorColor: RunovaColors.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? RunovaColors.primary
                : RunovaColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RunovaColors.primary,
          foregroundColor: RunovaColors.background,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

