import 'package:flutter/material.dart';

// Game-state colors stay stable on map overlays in either appearance.
abstract final class RunovaColors {
  static const primary = Color(0xFF318363);
  static const textMuted = Color(0xFF758078);
  static const warning = Color(0xFFB88736);
  static const danger = Color(0xFFD85454);
  static const enemy = Color(0xFFE57662);
}

abstract final class RunovaTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = Color(dark ? 0xFF141917 : 0xFFF5F6F2);
    final surface = Color(dark ? 0xFF1E2521 : 0xFFFFFFFF);
    final ink = Color(dark ? 0xFFF1F4EE : 0xFF202923);
    final muted = Color(dark ? 0xFFACB7AE : 0xFF647168);
    final accent = Color(dark ? 0xFF9DD4B5 : 0xFF2E7055);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: accent,
          onPrimary: dark ? const Color(0xFF183C2B) : Colors.white,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerHighest: Color(dark ? 0xFF2B352E : 0xFFEDF1EA),
          outlineVariant: Color(dark ? 0xFF354038 : 0xFFE3E8E0),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 28),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: ink,
        indicatorColor: dark
            ? const Color(0xFFCEDFD1)
            : const Color(0xFFE5EDE2),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: background,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF202923)
                : background,
            size: 23,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: background,
          minimumSize: const Size(0, 54),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: ink, fontSize: 12, fontFamily: 'Roboto'),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      ),
    );
  }
}
