import 'package:flutter/material.dart';

import '../design/glass_tokens.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentDeep,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.ice,
      onSecondary: Color(0xFF062033),
      surface: AppColors.surface1,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surface3,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFF3B1116),
      onErrorContainer: Color(0xFFFFD9DA),
      outline: AppColors.border,
      outlineVariant: AppColors.borderSoft,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accentDeep,
    );

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.accent.withValues(alpha: 0.10),
      highlightColor: Colors.white.withValues(alpha: 0.035),
      dividerColor: AppColors.borderSoft,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _LiquidTransitionsBuilder(),
          TargetPlatform.iOS: _LiquidTransitionsBuilder(),
          TargetPlatform.macOS: _LiquidTransitionsBuilder(),
          TargetPlatform.windows: _LiquidTransitionsBuilder(),
          TargetPlatform.linux: _LiquidTransitionsBuilder(),
        },
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      primaryIconTheme: const IconThemeData(color: AppColors.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.text,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          fontFamily: AppTypography.family,
          color: AppColors.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.family,
          color: AppColors.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        errorStyle: const TextStyle(
          fontFamily: AppTypography.family,
          color: AppColors.danger,
          fontSize: 12,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentBright,
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface3,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.family,
          color: AppColors.text,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 14.5,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surface3,
        circularTrackColor: AppColors.surface3,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.textTertiary.withValues(alpha: 0.45)),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surface4,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          fontFamily: AppTypography.family,
          color: AppColors.text,
          fontSize: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.surface4;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.surface2;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.textTertiary;
        }),
      ),
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
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: GlassTokens.easeOut,
      reverseCurve: GlassTokens.easeOut,
    );

    return RepaintBoundary(
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.035, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
