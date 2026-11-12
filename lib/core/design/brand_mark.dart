import 'package:flutter/material.dart';

/// The official WeBrand horizontal logo / wordmark.
/// Dynamically displays [webrand_2.png] on dark mode and [webrand_1.png] on light mode.
class WeBrandWordmark extends StatelessWidget {
  const WeBrandWordmark({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark
        ? 'assets/images/webrand_2.png'
        : 'assets/images/webrand_1.png';

    // Height scaled proportional to requested fontSize
    final height = fontSize * 1.35;

    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'WeBrand',
    );
  }
}

/// Backwards compatibility alias for [WeBrandWordmark].
typedef SabtWordmark = WeBrandWordmark;

/// Official launcher mark: WeBrand logo icon.
class WeBrandGlassMark extends StatelessWidget {
  const WeBrandGlassMark({super.key, this.size = 72});

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
          'assets/images/webrand_4.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'WeBrand',
        ),
      ),
    );
  }
}

/// Backwards compatibility alias for [WeBrandGlassMark].
typedef SabtGlassMark = WeBrandGlassMark;
