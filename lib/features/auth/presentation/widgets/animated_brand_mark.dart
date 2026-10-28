import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/brand_mark.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// Official Sabt icon on the splash and login screens, mounted inside a
/// tactile 3D squircle pedestal with a physical bottom ledge.
///
/// Tickers stop under reduced motion and when the route is covered.
class AnimatedBrandMark extends StatefulWidget {
  const AnimatedBrandMark({super.key, this.size = 84, this.playEntrance = true});

  final double size;

  /// Splash plays its own arrival. Login already staggers the mark, so a
  /// second scale on top of that makes the icon overshoot its slot.
  final bool playEntrance;

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
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playEntrance) {
      _entrance.forward();
    } else {
      _entrance.value = 1;
    }
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
    final palette = context.palette;
    final radius = size * 0.25;
    final lipColor = palette.isDark
        ? const Color(0xFF04060B)
        : const Color(0xFFD0D8EA);

    return RepaintBoundary(
      child: SizedBox(
        width: size * 1.18,
        height: size * 1.18,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entrance, _breath]),
          builder: (context, _) {
            final enter = Motion.easeOut.transform(_entrance.value.clamp(0, 1));
            final breath = Motion.easeInOut.transform(_breath.value);
            final floatY = math.sin(breath * math.pi) * -2.0;

            return Opacity(
              opacity: enter.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, floatY + (1 - enter) * 10),
                child: Transform.scale(
                  scale: 0.96 + 0.04 * enter,
                  filterQuality: FilterQuality.high,
                  child: Center(
                    child: Container(
                      width: size + 8,
                      height: size + 8,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: palette.surface1,
                        borderRadius: BorderRadius.circular(radius + 3),
                        border: Border.all(
                          color: palette.border,
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: lipColor,
                            offset: const Offset(0, 3.5),
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: palette.brandPurple.withValues(
                              alpha: palette.isDark ? 0.24 : 0.14,
                            ),
                            offset: const Offset(0, 12),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: SabtGlassMark(size: size),
                    ),
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
