import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The wordmark used in the web shell: lowercase "sabt" plus the red dot.
class SabtWordmark extends StatelessWidget {
  const SabtWordmark({
    super.key,
    this.fontSize = 26,
    this.color,
    this.showDot = true,
  });

  final double fontSize;
  final Color? color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'sabt',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            color: color ?? context.palette.text,
          ),
        ),
        if (showDot)
          Padding(
            padding: EdgeInsets.only(left: fontSize * 0.055, bottom: fontSize * 0.12),
            child: Container(
              width: fontSize * 0.16,
              height: fontSize * 0.16,
              decoration: BoxDecoration(
                color: context.palette.brandRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Official launcher mark: the white S and red dot on black.
class SabtGlassMark extends StatelessWidget {
  const SabtGlassMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/brand/sabt_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Sabt',
        ),
      ),
    );
  }
}
