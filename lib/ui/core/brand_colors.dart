import 'package:flutter/material.dart';

/// The djym palette. Screens use the [ColorScheme] built from it; these are
/// for the few brand touches outside the scheme's roles.
abstract final class BrandColors {
  static const deepTeal = Color(0xFF1A535C);
  static const turquoise = Color(0xFF4ECDC4);
  static const mint = Color(0xFFF7FFF7);
  static const coral = Color(0xFFFF6B6B);
  static const sunshine = Color(0xFFFFE66D);

  /// Grey-blue shades the dark theme is built on, so turquoise and coral
  /// stand out against a neutral night instead of a saturated teal.
  static const ink = Color(0xFF141E24);
  static const slate = Color(0xFF22313A);
}
