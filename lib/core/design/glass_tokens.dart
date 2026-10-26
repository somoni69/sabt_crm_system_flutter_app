import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

  // Durations (strictly under 300ms, tuned for 120 FPS)
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 260);

  // Canonical curves (Emil Kowalski Animation Engineering Paradigm)
  // Hard ban on ease-in: entrances and exits must always be snappy ease-out.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const Curve easeDrawer = Cubic(0.32, 0.72, 0, 1);
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
        Color.alphaBlend(Colors.white.withValues(alpha: strong ? 0.10 : 0.055), base),
        base,
        Color.alphaBlend(AppColors.accent.withValues(alpha: strong ? 0.08 : 0.035), base),
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
