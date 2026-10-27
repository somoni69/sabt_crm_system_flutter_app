import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Optical tokens and motion physics for the Liquid Glass layer.
abstract final class GlassTokens {
  // Diffusion / Blur (Liquid Glass HIG specification)
  static const double blurSmall = 8;
  static const double blurMedium = 16;
  static const double blurLarge = 24;
  static const double blurXl = 32;

  // Curvature
  static const double radiusSmall = 14;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;
  static const double radiusPill = 999;

  // Specular rim stroke
  static const double hairline = 1.2;

  // Aliases of [Motion]. fast matches the 120ms value landed on main.
  static const Duration fast = Motion.micro;
  static const Duration medium = Motion.standard;
  static const Duration slow = Duration(milliseconds: 260);

  static const Curve easeOut = Motion.easeOut;
  static const Curve easeInOut = Motion.easeInOut;
  static const Curve easeDrawer = Motion.drawer;

  /// Overshoot curve. Not for UI entrances. Gesture springs live on the nav bar.
  static const Curve springOut = Cubic(0.16, 1.08, 0.3, 1);

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
    return !MediaQuery.highContrastOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
  }

  static bool motionAllowed(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
}
