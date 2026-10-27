import 'package:flutter/material.dart';

import '../../../core/design/brand_mark.dart';
import '../../../core/design/glass_surface.dart';
import '../../auth/presentation/widgets/animated_brand_mark.dart';
import '../../../core/design/glass_tokens.dart';
import '../../../core/design/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: MotionAppear(
            duration: Motion.standard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnimatedBrandMark(size: 92),
                const SizedBox(height: 22),
                const SabtWordmark(fontSize: 40),
                const SizedBox(height: 14),
                Text(
                  'Рабочее пространство WeBrand',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    letterSpacing: 0.2,
                    color: context.palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 42),
                GlassSurface(
                  radius: 999,
                  blur: GlassTokens.blurMedium,
                  shadow: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: context.palette.accentBright,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Синхронизация',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Sabt CRM · Душанбе',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                    color: context.palette.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
