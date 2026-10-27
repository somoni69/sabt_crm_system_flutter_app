import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'glass_tokens.dart';

/// One translucent layer per Z-plane. Never nest another [GlassSurface]
/// inside it — children must be solid surfaces or outline chips.
///
/// [blurBackdrop] keeps the live [BackdropFilter]. Persistent chrome should
/// pass false: the plate is then the opaque composite of [tint] over
/// [AppColors.background], with the same rim, and scrolling content does
/// not pay for a blur every frame.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = GlassTokens.radiusLarge,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.blur = GlassTokens.blurLarge,
    this.blurBackdrop = true,
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
  final bool blurBackdrop;
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
      final liveBlur = blurBackdrop && blur > 0;
      final rawTint = tint ?? AppColors.glassTint;
      final plateTint = liveBlur
          ? rawTint
          : Color.alphaBlend(rawTint, AppColors.background);
      final painted = DecoratedBox(
        decoration: BoxDecoration(
          gradient: GlassTokens.surfaceGradient(
            tint: plateTint,
            strong: strong,
          ),
        ),
        child: CustomPaint(
          foregroundPainter: border
              ? _GlassRimPainter(
                  radius: radius,
                  highlight: strong ? 0.42 : 0.32,
                )
              : null,
          child: Padding(padding: padding, child: content),
        ),
      );
      content = ClipRRect(
        borderRadius: radiusValue,
        clipBehavior: clipBehavior,
        child: liveBlur
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: painted,
              )
            : painted,
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
  const _GlassRimPainter({required this.radius, required this.highlight});

  final double radius;
  final double highlight;

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

    // Pill radii (999) are larger than the control. Clamp the specular arc to
    // the real corner so it stays on the capsule instead of drawing off-canvas.
    final inset = rect.deflate(2.2);
    final cap = size.shortestSide / 2;
    final corner = radius > cap ? cap : radius;
    final glint = Path()
      ..addArc(
        Rect.fromLTWH(inset.left, inset.top, corner * 2, corner * 2),
        3.02,
        0.84,
      );
    canvas.drawPath(
      glint,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: highlight),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.highlight != highlight;
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
