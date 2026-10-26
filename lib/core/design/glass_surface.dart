import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'glass_tokens.dart';

/// One translucent layer per Z-plane. Never nest another [GlassSurface]
/// inside it — children must be solid surfaces or outline chips.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = GlassTokens.radiusLarge,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.blur = GlassTokens.blurLarge,
    this.tint,
    this.strong = false,
    this.shadow = true,
    this.glow = false,
    this.border = true,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tint;
  final bool strong;
  final bool shadow;
  final bool glow;
  final bool border;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final allowTransparency = GlassTokens.transparencyAllowed(context);
    final radiusValue = BorderRadius.circular(radius);

    Widget content = child;

    if (allowTransparency) {
      content = ClipRRect(
        borderRadius: radiusValue,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: GlassTokens.surfaceGradient(tint: tint, strong: strong),
            ),
            child: CustomPaint(
              foregroundPainter: border
                  ? _GlassRimPainter(radius: radius)
                  : null,
              child: Padding(padding: padding, child: content),
            ),
          ),
        ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: strong ? AppColors.surface3 : AppColors.surface2,
          borderRadius: radiusValue,
          border: border
              ? Border.all(
                  color: strong ? AppColors.borderStrong : AppColors.border,
                  width: 1.2,
                )
              : null,
        ),
        padding: padding,
        child: content,
      );
    }

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radiusValue,
        boxShadow: [
          if (shadow) ...AppColors.glassShadow,
          if (glow)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.16),
              blurRadius: 46,
              spreadRadius: -6,
              offset: const Offset(0, 18),
            ),
        ],
      ),
      child: RepaintBoundary(child: content),
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(GlassTokens.hairline / 2),
      Radius.circular(radius),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = GlassTokens.hairline
      ..shader = GlassTokens.rimGradient().createShader(rect);

    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// A thin luminous rule used inside glass chrome.
class GlassHairline extends StatelessWidget {
  const GlassHairline({super.key, this.indent = 0, this.opacity = 0.08});

  final double indent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
