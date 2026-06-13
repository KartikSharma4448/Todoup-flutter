import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF22C55E);
  static const Color primaryDark = Color(0xFF16A34A);
  static const Color primaryLight = Color(0xFF4ADE80);
  static const Color scaffoldLight = Color(0xFFF8FAFC);
  static const Color scaffoldDark = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color mutedLight = Color(0xFFF1F5F9);
  static const Color mutedDark = Color(0xFF374151);
  static const Color textLight = Color(0xFF111827);
  static const Color textDark = Color(0xFFF9FAFB);
  static const Color subduedLight = Color(0xFF64748B);
  static const Color subduedDark = Color(0xFF9CA3AF);
  static const Color destructive = Color(0xFFEF4444);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(28));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(22));

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = ThemeData(brightness: brightness, useMaterial3: true)
        .textTheme
        .apply(
          bodyColor: isDark ? AppColors.textDark : AppColors.textLight,
          displayColor: isDark ? AppColors.textDark : AppColors.textLight,
        );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      error: AppColors.destructive,
      onError: Colors.white,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark ? AppColors.textDark : AppColors.textLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.mutedDark : Colors.white,
        hintStyle: TextStyle(
          color: isDark ? AppColors.subduedDark : AppColors.subduedLight,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.textDark : AppColors.textLight,
          fontWeight: FontWeight.w600,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? AppColors.surfaceDark : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return isDark ? AppColors.mutedDark : AppColors.mutedLight;
        }),
      ),
    );
  }
}
