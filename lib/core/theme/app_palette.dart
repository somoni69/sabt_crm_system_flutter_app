import 'package:flutter/material.dart';

/// Colour tokens copied from the web CRM (`frontend/src/index.css`).
///
/// Widgets read colours through `context.palette`. Dark is the web
/// graphite workspace, light is the web porcelain workspace. The action
/// colour is the web steel blue, not a separate violet.
///
/// [AppColors] remains the dark preset's constant source (used by the
/// few places without a build context) — new UI must not read it.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundDeep,
    required this.backgroundLift,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.border,
    required this.borderSoft,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.brandPurple,
    required this.brandRed,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.ice,
    required this.iceDeep,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.glassTint,
    required this.glassTintLight,
    required this.glassRim,
  });

  final Brightness brightness;

  // Canvas
  final Color background;
  final Color backgroundDeep;
  final Color backgroundLift;

  // Solid content surfaces (never put glass inside these)
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color surface4;

  // Lines
  final Color border;
  final Color borderSoft;
  final Color borderStrong;

  // Text
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Brand (anchor: #59479e in both themes)
  final Color brandPurple;
  final Color brandRed;
  final Color accent;
  final Color accentBright;
  final Color accentDeep;
  final Color ice;
  final Color iceDeep;

  // Semantics (the product rule: red = overdue/error, green = done)
  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;

  // Glass
  final Color glassTint;
  final Color glassTintLight;
  final Color glassRim;

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF191C22),
    backgroundDeep: Color(0xFF14171D),
    backgroundLift: Color(0xFF22262E),
    surface1: Color(0xFF22262E),
    surface2: Color(0xFF2A303A),
    surface3: Color(0xFF30353F),
    surface4: Color(0xFF3E4553),
    border: Color(0xFF3E4553),
    borderSoft: Color(0xFF30353F),
    borderStrong: Color(0xFF5A6574),
    text: Color(0xFFF4F7FA),
    textSecondary: Color(0xFFC5CED8),
    textTertiary: Color(0xFF8792A2),
    textDisabled: Color(0xFF5C6776),
    brandPurple: Color(0xFF6E96BE),
    brandRed: Color(0xFFEF4444),
    accent: Color(0xFF6E96BE),
    accentBright: Color(0xFF9BB8D4),
    accentDeep: Color(0xFF3E6A90),
    ice: Color(0xFF8FB4D4),
    iceDeep: Color(0xFF3E6A90),
    danger: Color(0xFFF07178),
    dangerSoft: Color(0x33F07178),
    success: Color(0xFF3DDC84),
    successSoft: Color(0x2E3DDC84),
    warning: Color(0xFFF5B84B),
    warningSoft: Color(0x2EF5B84B),
    info: Color(0xFF7EB6E0),
    infoSoft: Color(0x2E7EB6E0),
    glassTint: Color(0xFF22262E),
    glassTintLight: Color(0xFF2A303A),
    glassRim: Color(0xFF3E4553),
  );

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F5F8),
    backgroundDeep: Color(0xFFE2E7ED),
    backgroundLift: Color(0xFFFCFDFE),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F5F8),
    surface3: Color(0xFFE2E7ED),
    surface4: Color(0xFFCBD3DD),
    border: Color(0xFFE2E7ED),
    borderSoft: Color(0xFFE2E7ED),
    borderStrong: Color(0xFFCBD3DD),
    text: Color(0xFF141A22),
    textSecondary: Color(0xFF3E4C5C),
    textTertiary: Color(0xFF6C798A),
    textDisabled: Color(0xFF9AA5B3),
    brandPurple: Color(0xFF1E4263),
    brandRed: Color(0xFFD92D20),
    accent: Color(0xFF1E4263),
    accentBright: Color(0xFF345A7C),
    accentDeep: Color(0xFF14304A),
    ice: Color(0xFF345A7C),
    iceDeep: Color(0xFF8FB4D4),
    danger: Color(0xFFD92D20),
    dangerSoft: Color(0x1FD92D20),
    success: Color(0xFF12805C),
    successSoft: Color(0x1F12805C),
    warning: Color(0xFFB54708),
    warningSoft: Color(0x1FB54708),
    info: Color(0xFF175CD3),
    infoSoft: Color(0x1F175CD3),
    glassTint: Color(0xFFFFFFFF),
    glassTintLight: Color(0xFFF3F5F8),
    glassRim: Color(0xFFE2E7ED),
  );

  Color priority(String priority) => switch (priority) {
    'critical' => danger,
    'high' => warning,
    'medium' => info,
    _ => textTertiary,
  };

  Color status(String status) => switch (status) {
    'done' || 'completed' || 'published' => success,
    'in_progress' ||
    'preparing' ||
    'in_production' ||
    'on_review' ||
    'on_approval' => info,
    'cancelled' || 'archived' => textTertiary,
    'overdue' => danger,
    _ => textSecondary,
  };

  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  List<BoxShadow> get glassShadow => cardShadow;

  /// Glass rim light. On dark glass the rim is white light; on light
  /// glass it is a white top sheen over a slate edge.
  LinearGradient rimGradient({double angle = -0.7}) => LinearGradient(
    begin: Alignment(angle, -1),
    end: Alignment(-angle, 1),
    colors: isDark
        ? [
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.10),
          ]
        : [
            Colors.white.withValues(alpha: 0.85),
            const Color(0xFF161B2D).withValues(alpha: 0.10),
            const Color(0xFF161B2D).withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.45),
          ],
    stops: const [0.0, 0.36, 0.72, 1.0],
  );

  /// Flat web card. Stops stay uniform so text contrast does not depend
  /// on a decorative wash.
  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      isDark ? background : surface1,
      isDark ? background : surface1,
      isDark ? background : surface1,
    ],
  );

  Color get heroBorder => border;

  List<BoxShadow> get heroShadow => cardShadow;

  /// Flat web primary. The middle stop is the button colour tests look for.
  LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [accent, brandPurple, accentDeep],
  );

  /// Selected chips and segments: the same steel as a web `bg-primary-600`.
  Color get controlSelected => brandPurple;
  Color get onControlSelected => Colors.white;

  LinearGradient surfaceGradient({Color? tint, bool strong = false}) {
    final base = tint ?? (strong ? surface2 : surface1);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, base, base],
    );
  }

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? backgroundDeep,
    Color? backgroundLift,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? surface4,
    Color? border,
    Color? borderSoft,
    Color? borderStrong,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? brandPurple,
    Color? brandRed,
    Color? accent,
    Color? accentBright,
    Color? accentDeep,
    Color? ice,
    Color? iceDeep,
    Color? danger,
    Color? dangerSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
    Color? glassTint,
    Color? glassTintLight,
    Color? glassRim,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      backgroundDeep: backgroundDeep ?? this.backgroundDeep,
      backgroundLift: backgroundLift ?? this.backgroundLift,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      surface4: surface4 ?? this.surface4,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      brandPurple: brandPurple ?? this.brandPurple,
      brandRed: brandRed ?? this.brandRed,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentDeep: accentDeep ?? this.accentDeep,
      ice: ice ?? this.ice,
      iceDeep: iceDeep ?? this.iceDeep,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      glassTint: glassTint ?? this.glassTint,
      glassTintLight: glassTintLight ?? this.glassTintLight,
      glassRim: glassRim ?? this.glassRim,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(
    covariant ThemeExtension<AppPalette>? other,
    double t,
  ) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      backgroundDeep: mix(backgroundDeep, other.backgroundDeep),
      backgroundLift: mix(backgroundLift, other.backgroundLift),
      surface1: mix(surface1, other.surface1),
      surface2: mix(surface2, other.surface2),
      surface3: mix(surface3, other.surface3),
      surface4: mix(surface4, other.surface4),
      border: mix(border, other.border),
      borderSoft: mix(borderSoft, other.borderSoft),
      borderStrong: mix(borderStrong, other.borderStrong),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      textDisabled: mix(textDisabled, other.textDisabled),
      brandPurple: mix(brandPurple, other.brandPurple),
      brandRed: mix(brandRed, other.brandRed),
      accent: mix(accent, other.accent),
      accentBright: mix(accentBright, other.accentBright),
      accentDeep: mix(accentDeep, other.accentDeep),
      ice: mix(ice, other.ice),
      iceDeep: mix(iceDeep, other.iceDeep),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      info: mix(info, other.info),
      infoSoft: mix(infoSoft, other.infoSoft),
      glassTint: mix(glassTint, other.glassTint),
      glassTintLight: mix(glassTintLight, other.glassTintLight),
      glassRim: mix(glassRim, other.glassRim),
    );
  }
}

/// The one sanctioned way to read colours in widgets.
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
