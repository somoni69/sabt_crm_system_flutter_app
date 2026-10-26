import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Optical tokens for the Liquid Glass layer.
abstract final class GlassTokens {
  static const double blurSmall = 10;
  static const double blurMedium = 18;
  static const double blurLarge = 26;
  static const double blurXl = 36;

  static const double radiusSmall = 14;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;
  static const double radiusPill = 999;

  static const double hairline = 1.1;

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve springOut = Cubic(0.16, 1.08, 0.3, 1);
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);

  static LinearGradient rimGradient({double angle = -0.7}) => LinearGradient(
        begin: Alignment(angle, -1),
        end: Alignment(-angle, 1),
        colors: [
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.03),
          Colors.white.withValues(alpha: 0.14),
        ],
        stops: const [0.0, 0.36, 0.72, 1.0],
      );

  static LinearGradient surfaceGradient({Color? tint, bool strong = false}) {
    final base = tint ?? AppColors.glassTint;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(Colors.white.withValues(alpha: strong ? 0.10 : 0.055), base),
        base,
        Color.alphaBlend(AppColors.accent.withValues(alpha: strong ? 0.08 : 0.035), base),
      ],
      stops: const [0.0, 0.52, 1.0],
    );
  }

  static bool transparencyAllowed(BuildContext context) {
    final media = MediaQuery.of(context);
    return !media.highContrast && !media.accessibleNavigation;
  }

  static bool motionAllowed(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
}
