import 'package:flutter/material.dart';

import '../design/motion.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Material themes for both palettes.
///
/// One builder feeds [AppPalette.dark] and [AppPalette.light] into the
/// same component themes, so dark and light can never drift apart in
/// shape, spacing or typography — only colour moves. The palette itself
/// rides along as a [ThemeExtension] for `context.palette`.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark => _build(AppPalette.dark);
  static ThemeData get light => _build(AppPalette.light);

  static ThemeData _build(AppPalette palette) {
    final isDark = palette.isDark;
    final scheme = isDark
        ? ColorScheme.dark(
            primary: palette.accent,
            onPrimary: Colors.white,
            primaryContainer: palette.accentDeep,
            onPrimaryContainer: Colors.white,
            secondary: palette.ice,
            onSecondary: const Color(0xFF062033),
            surface: palette.surface1,
            onSurface: palette.text,
            surfaceContainerHighest: palette.surface3,
            onSurfaceVariant: palette.textSecondary,
            error: palette.danger,
            onError: Colors.white,
            errorContainer: const Color(0xFF3B1116),
            onErrorContainer: const Color(0xFFFFD9DA),
            outline: palette.border,
            outlineVariant: palette.borderSoft,
            shadow: Colors.black,
            scrim: Colors.black,
            inverseSurface: palette.text,
            onInverseSurface: palette.background,
            inversePrimary: palette.accentDeep,
          )
        : ColorScheme.light(
            primary: palette.accent,
            onPrimary: Colors.white,
            primaryContainer: palette.accentDeep,
            onPrimaryContainer: Colors.white,
            secondary: palette.ice,
            onSecondary: Colors.white,
            surface: palette.surface1,
            onSurface: palette.text,
            surfaceContainerHighest: palette.surface3,
            onSurfaceVariant: palette.textSecondary,
            error: palette.danger,
            onError: Colors.white,
            errorContainer: const Color(0xFFFDECEA),
            onErrorContainer: const Color(0xFF8F1D13),
            outline: palette.border,
            outlineVariant: palette.borderSoft,
            shadow: Colors.black,
            scrim: Colors.black,
            inverseSurface: palette.text,
            onInverseSurface: palette.background,
            inversePrimary: palette.accentDeep,
          );

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: palette.text,
      displayColor: palette.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: palette.background,
      splashFactory: InkRipple.splashFactory,
      splashColor: palette.accent.withValues(alpha: 0.10),
      highlightColor: (isDark ? Colors.white : Colors.black).withValues(
        alpha: 0.035,
      ),
      dividerColor: palette.borderSoft,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [palette],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _LiquidTransitionsBuilder(),
          TargetPlatform.iOS: _LiquidTransitionsBuilder(),
          TargetPlatform.macOS: _LiquidTransitionsBuilder(),
          TargetPlatform.windows: _LiquidTransitionsBuilder(),
          TargetPlatform.linux: _LiquidTransitionsBuilder(),
        },
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 20),
      primaryIconTheme: IconThemeData(color: palette.text),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: palette.text,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: palette.text,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          fontFamily: AppTypography.family,
          color: palette.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          fontFamily: AppTypography.family,
          color: palette.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: palette.textTertiary,
        suffixIconColor: palette.textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.accent, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.danger, width: 1.4),
        ),
        errorStyle: TextStyle(
          fontFamily: AppTypography.family,
          color: palette.danger,
          fontSize: 12,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentBright,
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.borderSoft,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surface3,
        contentTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          color: palette.text,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 14.5,
          height: 1.45,
          color: palette.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.surface3,
        circularTrackColor: palette.surface3,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          palette.textTertiary.withValues(alpha: 0.45),
        ),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surface4,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(
          fontFamily: AppTypography.family,
          color: palette.text,
          fontSize: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return palette.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.surface4;
        }),
        trackOutlineColor: WidgetStateProperty.all(palette.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.surface2;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: palette.borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.textTertiary;
        }),
      ),
    );
  }
}

/// Pins its subtree to the dark palette, whatever the app theme is.
///
/// For surfaces that are dark by design in both themes — the gradient
/// hero cards (day focus, project/task/profile headers). Without this
/// scope, a hero's text reads `context.palette` from the LIGHT theme
/// in light mode and renders dark-on-dark. Inside [OnDark], palette,
/// colour scheme and text theme all resolve to the dark preset, so the
/// hero is a self-contained dark world.
class OnDark extends StatelessWidget {
  const OnDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        colorScheme: dark.colorScheme,
        textTheme: dark.textTheme,
        extensions: [AppPalette.dark],
      ),
      child: child,
    );
  }
}

class _LiquidTransitionsBuilder extends PageTransitionsBuilder {
  const _LiquidTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!Motion.allowed(context)) return child;
    return MotionPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
