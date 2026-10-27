import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/motion.dart';

Page<T> motionPage<T>({
  required BuildContext context,
  required LocalKey pageKey,
  required Widget child,
}) {
  final enabled = Motion.allowed(context);
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: enabled ? Motion.standard : Duration.zero,
    reverseTransitionDuration: enabled ? Motion.exit : Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (!Motion.allowed(context)) return child;
      return MotionPageTransition(animation: animation, child: child);
    },
  );
}
