import 'package:flutter/material.dart';

import '../../../core/design/brand_mark.dart';
import '../../../core/design/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/animated_brand_mark.dart';
import '../../auth/presentation/widgets/login_background.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lipColor = palette.isDark
        ? const Color(0xFF05070C)
        : const Color(0xFFD5DCEB);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: LoginBackground()),
          SafeArea(
            child: Center(
              child: MotionAppear(
                duration: Motion.standard,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedBrandMark(size: 88),
                    const SizedBox(height: 22),
                    const SabtWordmark(fontSize: 38),
                    const SizedBox(height: 10),
                    Text(
                      'Рабочее пространство WeBrand',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface1,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: lipColor,
                            offset: const Offset(0, 2.5),
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: palette.isDark ? 0.28 : 0.06,
                            ),
                            offset: const Offset(0, 8),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: palette.brandPurple,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Синхронизация',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Sabt CRM · Душанбе',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w500,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
