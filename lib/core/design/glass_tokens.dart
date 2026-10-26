import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

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

  static const Duration fast = Motion.exit;
  static const Duration medium = Motion.standard;
  static const Duration slow = Motion.sheet;

  /// Overshoot curve. Not for UI entrances. Gesture springs live on the nav bar.
  static const Curve springOut = Cubic(0.16, 1.08, 0.3, 1);
  static const Curve easeOut = Motion.easeOut;

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
        Color.alphaBlend(
          Colors.white.withValues(alpha: strong ? 0.10 : 0.055),
          base,
        ),
        base,
        Color.alphaBlend(
          AppColors.accent.withValues(alpha: strong ? 0.08 : 0.035),
          base,
        ),
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
