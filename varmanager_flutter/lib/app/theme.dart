import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF1F5E5B);
  static const _secondary = Color(0xFFB86B2B);
  static const _surface = Color(0xFFF7F3EE);
  static const _background = Color(0xFFF2EEE9);
  static const _onSurface = Color(0xFF1C1B1A);

  static ThemeData build() {
    final scheme = const ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.white,
      surface: _surface,
      onSurface: _onSurface,
      background: _background,
      onBackground: _onSurface,
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      fontFamily: 'Bahnschrift',
    );

    final cardTheme = CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'Cambria',
          fontWeight: FontWeight.w600,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _onSurface,
        elevation: 0,
      ),
      cardTheme: cardTheme,
    );
  }
}
