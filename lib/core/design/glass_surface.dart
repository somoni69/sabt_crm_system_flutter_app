import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import 'glass_tokens.dart';

/// One translucent layer per Z-plane. Never nest another [GlassSurface]
/// inside it — children must be solid surfaces or outline chips.
///
/// [blurBackdrop] keeps the live [BackdropFilter]. Persistent chrome should
/// pass false: the plate is then the opaque composite of [tint] over the
/// palette background, with the same rim, and scrolling content does
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
    final palette = context.palette;
    final allowTransparency = GlassTokens.transparencyAllowed(context);
    final radiusValue = BorderRadius.circular(radius);

    Widget content = child;

    if (allowTransparency) {
      final liveBlur = blurBackdrop && blur > 0;
      final rawTint = tint ?? palette.glassTint;
      final plateTint = liveBlur
          ? rawTint
          : Color.alphaBlend(rawTint, palette.background);
      final painted = DecoratedBox(
        decoration: BoxDecoration(
          gradient: palette.surfaceGradient(
            tint: plateTint,
            strong: strong,
          ),
        ),
        child: CustomPaint(
          foregroundPainter: border
              ? _GlassRimPainter(radius: radius, palette: palette)
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
          color: strong ? palette.surface3 : palette.surface2,
          borderRadius: radiusValue,
          border: border
              ? Border.all(
                  color: strong ? palette.borderStrong : palette.border,
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
          if (shadow) ...palette.glassShadow,
          if (glow)
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.16),
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

/// Specular rim used by glass plates and by buttons that sit on them.
/// Buttons must not nest a second [GlassSurface]: the rim is enough to
/// keep them in the same material.
class GlassRim extends StatelessWidget {
  const GlassRim({super.key, required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _GlassRimPainter(
        radius: radius,
        palette: context.palette,
      ),
      child: child,
    );
  }
}

/// The glass rim: one hairline stroke around the surface, brighter at
/// the top-left where light would catch it.
///
/// Deliberately nothing else. An earlier version also drew a specular
/// arc inside the top-left corner; on wide pills (headers, the nav
/// capsule) that arc read as a stray stripe floating inside the glass,
/// so it was removed — the gradient stroke alone carries the effect.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.radius, required this.palette});

  final double radius;
  final AppPalette palette;

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
      ..shader = palette.rimGradient().createShader(rect);

    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.palette != palette;
}

/// A thin luminous rule used inside glass chrome.
class GlassHairline extends StatelessWidget {
  const GlassHairline({super.key, this.indent = 0, this.opacity = 0.08});

  final double indent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final line = context.palette.isDark ? Colors.white : context.palette.text;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              line.withValues(alpha: 0),
              line.withValues(alpha: opacity),
              line.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
