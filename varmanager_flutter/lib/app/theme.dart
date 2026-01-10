import 'package:flutter/material.dart';

enum AppThemeType {
  defaultTheme('Default', Icons.palette_outlined),
  ocean('Ocean Blue', Icons.water_drop_outlined),
  forest('Forest Green', Icons.forest_outlined),
  rose('Rose', Icons.local_florist_outlined),
  dark('Dark', Icons.dark_mode_outlined);

  final String label;
  final IconData icon;
  const AppThemeType(this.label, this.icon);
}

class AppTheme {
  // Default theme colors (原有主题)
  static const _defaultPrimary = Color(0xFF1F5E5B);
  static const _defaultSecondary = Color(0xFFB86B2B);
  static const _defaultSurface = Color(0xFFF7F3EE);
  static const _defaultBackground = Color(0xFFF2EEE9);
  static const _defaultOnSurface = Color(0xFF1C1B1A);

  // Ocean Blue theme colors
  static const _oceanPrimary = Color(0xFF1565C0);
  static const _oceanSecondary = Color(0xFF0288D1);
  static const _oceanSurface = Color(0xFFF5F9FC);
  static const _oceanBackground = Color(0xFFECF4FA);
  static const _oceanOnSurface = Color(0xFF1A237E);

  // Forest Green theme colors
  static const _forestPrimary = Color(0xFF2E7D32);
  static const _forestSecondary = Color(0xFF558B2F);
  static const _forestSurface = Color(0xFFF1F8E9);
  static const _forestBackground = Color(0xFFE8F5E9);
  static const _forestOnSurface = Color(0xFF1B5E20);

  // Rose theme colors
  static const _rosePrimary = Color(0xFFC2185B);
  static const _roseSecondary = Color(0xFFE91E63);
  static const _roseSurface = Color(0xFFFCF4F6);
  static const _roseBackground = Color(0xFFFCE4EC);
  static const _roseOnSurface = Color(0xFF4A1942);

  // Dark theme colors
  static const _darkPrimary = Color(0xFF80CBC4);
  static const _darkSecondary = Color(0xFFFFAB91);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _darkBackground = Color(0xFF121212);
  static const _darkOnSurface = Color(0xFFE0E0E0);

  static ThemeData build([AppThemeType type = AppThemeType.defaultTheme]) {
    switch (type) {
      case AppThemeType.defaultTheme:
        return _buildTheme(
          brightness: Brightness.light,
          primary: _defaultPrimary,
          secondary: _defaultSecondary,
          surface: _defaultSurface,
          background: _defaultBackground,
          onSurface: _defaultOnSurface,
        );
      case AppThemeType.ocean:
        return _buildTheme(
          brightness: Brightness.light,
          primary: _oceanPrimary,
          secondary: _oceanSecondary,
          surface: _oceanSurface,
          background: _oceanBackground,
          onSurface: _oceanOnSurface,
        );
      case AppThemeType.forest:
        return _buildTheme(
          brightness: Brightness.light,
          primary: _forestPrimary,
          secondary: _forestSecondary,
          surface: _forestSurface,
          background: _forestBackground,
          onSurface: _forestOnSurface,
        );
      case AppThemeType.rose:
        return _buildTheme(
          brightness: Brightness.light,
          primary: _rosePrimary,
          secondary: _roseSecondary,
          surface: _roseSurface,
          background: _roseBackground,
          onSurface: _roseOnSurface,
        );
      case AppThemeType.dark:
        return _buildTheme(
          brightness: Brightness.dark,
          primary: _darkPrimary,
          secondary: _darkSecondary,
          surface: _darkSurface,
          background: _darkBackground,
          onSurface: _darkOnSurface,
        );
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color background,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;

    // Dark模式需要特殊处理对比度
    final onPrimary = isDark ? const Color(0xFF003733) : Colors.white;
    final onSecondary = isDark ? const Color(0xFF442B20) : Colors.white;

    // Container颜色 - Dark模式使用更深的容器色
    final primaryContainer = isDark
        ? const Color(0xFF004D47)
        : primary.withValues(alpha: 0.12);
    final onPrimaryContainer = isDark
        ? const Color(0xFFA4F3EC)
        : primary;
    final secondaryContainer = isDark
        ? const Color(0xFF5D4037)
        : secondary.withValues(alpha: 0.12);
    final onSecondaryContainer = isDark
        ? const Color(0xFFFFDBCF)
        : secondary;

    // Surface变体
    final surfaceContainerHighest = isDark
        ? const Color(0xFF363636)
        : onSurface.withValues(alpha: 0.05);
    final outline = isDark
        ? const Color(0xFF8E918F)
        : onSurface.withValues(alpha: 0.3);
    final outlineVariant = isDark
        ? const Color(0xFF444746)
        : onSurface.withValues(alpha: 0.12);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      errorContainer: isDark ? const Color(0xFF93000A) : const Color(0xFFF9DEDC),
      onErrorContainer: isDark ? const Color(0xFFFFDAD6) : const Color(0xFF410E0B),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Bahnschrift',
    );

    final cardTheme = CardThemeData(
      color: scheme.surface,
      elevation: isDark ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? outlineVariant : scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
    );

    // 按钮主题 - 确保Dark模式有足够对比度
    final filledButtonTheme = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: onPrimary,
        backgroundColor: primary,
      ),
    );

    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? primary : primary,
        side: BorderSide(color: isDark ? outline : primary.withValues(alpha: 0.5)),
      ),
    );

    final textButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
      ),
    );

    // Chip主题
    final chipTheme = ChipThemeData(
      backgroundColor: isDark ? surfaceContainerHighest : surface,
      labelStyle: TextStyle(color: onSurface),
      side: BorderSide(color: outlineVariant),
    );

    // DropdownButton主题
    final dropdownMenuTheme = DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: WidgetStatePropertyAll(surface),
      ),
    );

    // 输入框主题
    final inputDecorationTheme = InputDecorationTheme(
      filled: isDark,
      fillColor: isDark ? surfaceContainerHighest : null,
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primary, width: 2),
      ),
    );

    // 导航栏主题
    final navigationBarTheme = NavigationBarThemeData(
      backgroundColor: isDark ? surface : background,
      indicatorColor: primaryContainer,
    );

    final navigationRailTheme = NavigationRailThemeData(
      backgroundColor: isDark ? surface : background,
      indicatorColor: primaryContainer,
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
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? surface : background,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: cardTheme,
      filledButtonTheme: filledButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme,
      chipTheme: chipTheme,
      dropdownMenuTheme: dropdownMenuTheme,
      inputDecorationTheme: inputDecorationTheme,
      navigationBarTheme: navigationBarTheme,
      navigationRailTheme: navigationRailTheme,
      dividerColor: outlineVariant,
      dialogTheme: DialogThemeData(backgroundColor: surface),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : null,
        contentTextStyle: TextStyle(color: isDark ? Colors.white : null),
      ),
    );
  }
}
