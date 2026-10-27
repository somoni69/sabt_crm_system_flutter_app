import 'package:flutter/material.dart';

/// The app's colour tokens as a [ThemeExtension].
///
/// Widgets read colours through `context.palette`, never from a static
/// palette, so the whole tree can switch between [AppPalette.dark]
/// ("liquid graphite") and [AppPalette.light] ("liquid porcelain")
/// without a restart. Both presets keep the canonical Sabt violet
/// #59479e as their anchor; only its tints move, enough to stay legible
/// on each canvas.
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
    background: Color(0xFF06080E),
    backgroundDeep: Color(0xFF04060A),
    backgroundLift: Color(0xFF0A0E17),
    surface1: Color(0xFF0F1420),
    surface2: Color(0xFF151B2A),
    surface3: Color(0xFF1C2435),
    surface4: Color(0xFF232D42),
    border: Color(0xFF243047),
    borderSoft: Color(0xFF1A2334),
    borderStrong: Color(0xFF344260),
    text: Color(0xFFF3F6FC),
    textSecondary: Color(0xFFA8B2C6),
    textTertiary: Color(0xFF71809A),
    textDisabled: Color(0xFF4E5A70),
    brandPurple: Color(0xFF59479E),
    brandRed: Color(0xFFEF4444),
    accent: Color(0xFF8B6CF6),
    accentBright: Color(0xFFB49BFF),
    accentDeep: Color(0xFF5B3EC8),
    ice: Color(0xFF7EC8FF),
    iceDeep: Color(0xFF2E6E9E),
    danger: Color(0xFFFF5C63),
    dangerSoft: Color(0x33FF5C63),
    success: Color(0xFF35D07F),
    successSoft: Color(0x2E35D07F),
    warning: Color(0xFFF5B84B),
    warningSoft: Color(0x2EF5B84B),
    info: Color(0xFF6AA6FF),
    infoSoft: Color(0x2E6AA6FF),
    glassTint: Color(0xB3131824),
    glassTintLight: Color(0x1AFFFFFF),
    glassRim: Color(0x40FFFFFF),
  );

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F4F9),
    backgroundDeep: Color(0xFFE9EBF3),
    backgroundLift: Color(0xFFFFFFFF),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF7F8FC),
    surface3: Color(0xFFEEF0F7),
    surface4: Color(0xFFE2E7F2),
    border: Color(0xFFD6DCEC),
    borderSoft: Color(0xFFE3E8F2),
    borderStrong: Color(0xFFB9C4DC),
    text: Color(0xFF161B2D),
    textSecondary: Color(0xFF49536D),
    textTertiary: Color(0xFF75809A),
    textDisabled: Color(0xFFA9B1C5),
    brandPurple: Color(0xFF59479E),
    brandRed: Color(0xFFD92D20),
    accent: Color(0xFF59479E),
    accentBright: Color(0xFF6D5BD0),
    accentDeep: Color(0xFF473A85),
    ice: Color(0xFF2E7FC2),
    iceDeep: Color(0xFF7EC8FF),
    danger: Color(0xFFD92D20),
    dangerSoft: Color(0x1FD92D20),
    success: Color(0xFF12805C),
    successSoft: Color(0x1F12805C),
    warning: Color(0xFFB54708),
    warningSoft: Color(0x1FB54708),
    info: Color(0xFF175CD3),
    infoSoft: Color(0x1F175CD3),
    glassTint: Color(0xC7FFFFFF),
    glassTintLight: Color(0x0F161B2D),
    glassRim: Color(0x2E161B2D),
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
      color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];

  List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
      blurRadius: 30,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: accent.withValues(alpha: isDark ? 0.08 : 0.10),
      blurRadius: 40,
      offset: const Offset(0, 10),
    ),
  ];

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

  LinearGradient surfaceGradient({Color? tint, bool strong = false}) {
    final base = tint ?? glassTint;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          Colors.white.withValues(alpha: strong ? 0.10 : 0.055),
          base,
        ),
        base,
        Color.alphaBlend(accent.withValues(alpha: strong ? 0.08 : 0.035), base),
      ],
      stops: const [0.0, 0.52, 1.0],
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
