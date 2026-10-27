import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/brand_mark.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// The Sabt glass sphere, alive.
///
/// Three layers, each deliberately cheap:
/// * entrance — a single spring scale/fade as the mark lands;
/// * breathing — a slow glow pulse and a 3 px float, so the screen feels
///   awake while the user types. Transform and opacity only;
/// * specular sweep — a soft light band crossing the sphere on the same
///   breathing phase, clipped to the circle.
///
/// All tickers stop under reduced motion and when the route is covered
/// (the framework's [TickerMode] handles the latter). The whole mark is
/// a [RepaintBoundary]: its glow never repaints the form behind it.
class AnimatedBrandMark extends StatefulWidget {
  const AnimatedBrandMark({super.key, this.size = 84});

  final double size;

  @override
  State<AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends State<AnimatedBrandMark>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void initState() {
    super.initState();
    _entrance.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.allowed(context)) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0.4;
      if (_entrance.value != 1) _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return RepaintBoundary(
      child: SizedBox(
        width: size * 1.24,
        height: size * 1.24,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entrance, _breath]),
          builder: (context, _) {
            final enter = Motion.spring.transform(_entrance.value.clamp(0, 1));
            final breath = Motion.easeInOut.transform(_breath.value);
            final floatY = math.sin(breath * math.pi) * -3;
            final glowScale = 1 + breath * 0.10;

            return Opacity(
              opacity: enter.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, floatY + (1 - enter) * 10),
                child: Transform.scale(
                  scale: 0.82 + 0.18 * enter,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Breathing halo behind the sphere.
                      Transform.scale(
                        scale: glowScale,
                        child: Container(
                          width: size * 1.18,
                          height: size * 1.18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                context.palette.accent.withValues(
                                  alpha: 0.30 + breath * 0.14,
                                ),
                                context.palette.accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SabtGlassMark(size: size, glow: false),
                      // Specular sweep, clipped to the sphere.
                      SizedBox(
                        width: size * 0.86,
                        height: size * 0.86,
                        child: ClipOval(
                          child: Transform.translate(
                            offset: Offset(
                              -size * 0.9 + breath * size * 1.8,
                              -size * 0.18,
                            ),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Container(
                                width: size * 0.34,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.14),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
