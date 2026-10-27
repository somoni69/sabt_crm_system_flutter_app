import 'package:flutter/material.dart';

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

  // Colour-bearing glass gradients (rim, surface) live on AppPalette:
  // they differ between the dark and light themes. This class keeps
  // only theme-independent optics: blur, radii, timing.

  static bool transparencyAllowed(BuildContext context) {
    return !MediaQuery.highContrastOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
  }

  static bool motionAllowed(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
}
