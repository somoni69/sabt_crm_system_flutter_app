import 'package:flutter/material.dart';

export 'app_palette.dart';

/// Dark preset of the web CRM palette. Widgets must read colours via
/// `context.palette` so light mode can take over. Red stays overdue,
/// green stays done.
abstract final class AppColors {
  static const Color background = Color(0xFF191C22);
  static const Color backgroundDeep = Color(0xFF14171D);
  static const Color backgroundLift = Color(0xFF22262E);

  static const Color surface1 = Color(0xFF22262E);
  static const Color surface2 = Color(0xFF2A303A);
  static const Color surface3 = Color(0xFF30353F);
  static const Color surface4 = Color(0xFF3E4553);

  static const Color border = Color(0xFF3E4553);
  static const Color borderSoft = Color(0xFF30353F);
  static const Color borderStrong = Color(0xFF5A6574);

  static const Color text = Color(0xFFF4F7FA);
  static const Color textSecondary = Color(0xFFC5CED8);
  static const Color textTertiary = Color(0xFF8792A2);
  static const Color textDisabled = Color(0xFF5C6776);

  static const Color brandPurple = Color(0xFF6E96BE);
  static const Color brandRed = Color(0xFFEF4444);
  static const Color accent = Color(0xFF6E96BE);
  static const Color accentBright = Color(0xFF9BB8D4);
  static const Color accentDeep = Color(0xFF3E6A90);
  static const Color ice = Color(0xFF8FB4D4);
  static const Color iceDeep = Color(0xFF3E6A90);

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
