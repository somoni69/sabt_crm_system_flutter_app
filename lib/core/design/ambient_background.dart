import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Flat page canvas. The shell used to keep a full-screen ticker here
/// even after the paint became a single colour; that tick never went
/// idle and kept the GPU awake on both Android and iOS.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.palette.background);
  }
}
