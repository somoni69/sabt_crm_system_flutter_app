import 'package:flutter/material.dart';

/// Brand palette: "liquid graphite" — near-black glass with the sabt violet
/// and the red brand dot. Red is reserved for overdue/errors, green for done.
abstract final class AppColors {
  // Canvas
  static const Color background = Color(0xFF06080E);
  static const Color backgroundDeep = Color(0xFF04060A);
  static const Color backgroundLift = Color(0xFF0A0E17);

  // Solid content surfaces (never put glass inside these)
  static const Color surface1 = Color(0xFF0F1420);
  static const Color surface2 = Color(0xFF151B2A);
  static const Color surface3 = Color(0xFF1C2435);
  static const Color surface4 = Color(0xFF232D42);

  // Lines
  static const Color border = Color(0xFF243047);
  static const Color borderSoft = Color(0xFF1A2334);
  static const Color borderStrong = Color(0xFF344260);

  // Text
  static const Color text = Color(0xFFF3F6FC);
  static const Color textSecondary = Color(0xFFA8B2C6);
  static const Color textTertiary = Color(0xFF71809A);
  static const Color textDisabled = Color(0xFF4E5A70);

  // Brand
  static const Color brandPurple = Color(0xFF6B4FCF);
  static const Color brandRed = Color(0xFFEF4444);
  static const Color accent = Color(0xFF8B6CF6);
  static const Color accentBright = Color(0xFFB49BFF);
  static const Color accentDeep = Color(0xFF5B3EC8);
  static const Color ice = Color(0xFF7EC8FF);
  static const Color iceDeep = Color(0xFF2E6E9E);

  // Semantics (the product rule: red = overdue/error, green = done)
  static const Color danger = Color(0xFFFF5C63);
  static const Color dangerSoft = Color(0x33FF5C63);
  static const Color success = Color(0xFF35D07F);
  static const Color successSoft = Color(0x2E35D07F);
  static const Color warning = Color(0xFFF5B84B);
  static const Color warningSoft = Color(0x2EF5B84B);
  static const Color info = Color(0xFF6AA6FF);
  static const Color infoSoft = Color(0x2E6AA6FF);

  // Glass
  static const Color glassTint = Color(0xB3131824);
  static const Color glassTintLight = Color(0x1AFFFFFF);
  static const Color glassRim = Color(0x40FFFFFF);

  static Color priority(String priority) => switch (priority) {
        'critical' => danger,
        'high' => warning,
        'medium' => info,
        _ => textTertiary,
      };

  static Color status(String status) => switch (status) {
        'done' || 'completed' || 'published' => success,
        'in_progress' || 'preparing' || 'in_production' || 'on_review' || 'on_approval' => info,
        'cancelled' || 'archived' => textTertiary,
        'overdue' => danger,
        _ => textSecondary,
      };

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.08),
          blurRadius: 40,
          offset: const Offset(0, 10),
        ),
      ];
}
