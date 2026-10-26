
import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String family = 'IBMPlexSans';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: family,
      fontSize: 44,
      height: 1.04,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.4,
      fontFeatures: tabular,
    ),
    displayMedium: TextStyle(
      fontFamily: family,
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      fontFeatures: tabular,
    ),
    headlineLarge: TextStyle(
      fontFamily: family,
      fontSize: 28,
      height: 1.12,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    ),
    headlineMedium: TextStyle(
      fontFamily: family,
      fontSize: 24,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontFamily: family,
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    ),
    titleLarge: TextStyle(
      fontFamily: family,
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
    ),
    titleMedium: TextStyle(
      fontFamily: family,
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: family,
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontFamily: family,
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: family,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.25,
    ),
    labelSmall: TextStyle(
      fontFamily: family,
      fontSize: 10.5,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    ),
  );

  static TextStyle number({
    double size = 32,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.05,
        fontWeight: weight,
        letterSpacing: -0.8,
        fontFeatures: tabular,
        color: color,
      );

  static TextStyle overline({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: color,
      );
}
