import 'package:flutter/material.dart';
import 'package:loggym/domain/theme_preference.dart';
import 'package:loggym/ui/core/brand_colors.dart';

/// Roles come straight from the palette; containers and text use tints and
/// shades of it so contrast holds in both themes. Dark surfaces sit on the
/// neutral ink and slate shades.
abstract final class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: BrandColors.deepTeal,
    onPrimary: BrandColors.mint,
    primaryContainer: BrandColors.turquoise,
    onPrimaryContainer: Color(0xFF0B3237),
    secondary: Color(0xFF2F8A8F),
    onSecondary: BrandColors.mint,
    secondaryContainer: Color(0xFFCDF2EE),
    onSecondaryContainer: BrandColors.deepTeal,
    tertiary: Color(0xFF8A7300),
    onTertiary: BrandColors.mint,
    tertiaryContainer: BrandColors.sunshine,
    onTertiaryContainer: BrandColors.deepTeal,
    error: Color(0xFFC93C3C),
    onError: BrandColors.mint,
    errorContainer: Color(0xFFFFDADA),
    onErrorContainer: Color(0xFF6B1D1D),
    surface: BrandColors.mint,
    onSurface: Color(0xFF12393F),
    onSurfaceVariant: Color(0xFF45666B),
    surfaceDim: Color(0xFFD6E7E4),
    surfaceBright: BrandColors.mint,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0FAF7),
    surfaceContainer: Color(0xFFE8F6F3),
    surfaceContainerHigh: Color(0xFFE0F2EF),
    surfaceContainerHighest: Color(0xFFD6EDEA),
    outline: Color(0xFF7A999C),
    outlineVariant: Color(0xFFC3DCD9),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: BrandColors.deepTeal,
    onInverseSurface: BrandColors.mint,
    inversePrimary: BrandColors.turquoise,
    surfaceTint: BrandColors.deepTeal,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BrandColors.turquoise,
    onPrimary: BrandColors.ink,
    primaryContainer: BrandColors.turquoise,
    onPrimaryContainer: BrandColors.ink,
    secondary: Color(0xFF94DFD9),
    onSecondary: BrandColors.ink,
    secondaryContainer: Color(0xFF1F4B52),
    onSecondaryContainer: Color(0xFFD3F5F2),
    tertiary: BrandColors.sunshine,
    onTertiary: BrandColors.ink,
    tertiaryContainer: Color(0xFF4D4626),
    onTertiaryContainer: Color(0xFFFFF4BF),
    error: BrandColors.coral,
    onError: Color(0xFF4A1010),
    errorContainer: Color(0xFF6E2A2C),
    onErrorContainer: Color(0xFFFFDADA),
    surface: BrandColors.ink,
    onSurface: BrandColors.mint,
    onSurfaceVariant: Color(0xFFA9BCC4),
    surfaceDim: BrandColors.ink,
    surfaceBright: Color(0xFF34464F),
    surfaceContainerLowest: Color(0xFF0E161A),
    surfaceContainerLow: Color(0xFF19252C),
    surfaceContainer: Color(0xFF1D2A32),
    surfaceContainerHigh: BrandColors.slate,
    surfaceContainerHighest: Color(0xFF2A3B45),
    outline: Color(0xFF6F8791),
    outlineVariant: Color(0xFF34464F),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: BrandColors.mint,
    onInverseSurface: BrandColors.deepTeal,
    inversePrimary: BrandColors.deepTeal,
    surfaceTint: BrandColors.turquoise,
  );

  static final ThemeData light = _themeFrom(_lightScheme);

  static final ThemeData dark = _themeFrom(_darkScheme);

  static ThemeData _themeFrom(ColorScheme colors) {
    final base = ThemeData(colorScheme: colors);
    // Roboto throughout; headings get weight and slightly tighter tracking.
    TextStyle? heading(TextStyle? style) => style?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    );
    final text = base.textTheme;

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: heading(text.displayLarge),
        displayMedium: heading(text.displayMedium),
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      // App bars keep the page colour while content scrolls under them.
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        actionTextColor: colors.inversePrimary,
      ),
    );
  }

  static ThemeMode modeFor(ThemePreference preference) => switch (preference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}
