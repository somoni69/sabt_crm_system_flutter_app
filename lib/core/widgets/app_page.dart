import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/glass_tokens.dart';
import '../design/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_controls.dart';

abstract final class PageInsets {
  static double top(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 64;

  static double bottomNav(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 72;

  static double bottomPlain(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 28;
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.header,
    required this.slivers,
    this.onRefresh,
    this.controller,
    this.bottomPadding,
    this.floatingAction,
    this.footer,
    this.showBottomBarSpace = true,
    this.scrollPhysics,
  });

  final Widget header;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double? bottomPadding;
  final Widget? floatingAction;

  /// Pinned to the bottom of the screen, above the keyboard (chat
  /// composers, sticky action bars). Scroll content must reserve room
  /// for it via [bottomPadding].
  final Widget? footer;
  final bool showBottomBarSpace;
  final ScrollPhysics? scrollPhysics;

  @override
  Widget build(BuildContext context) {
    final top = PageInsets.top(context);
    final bottom =
        bottomPadding ??
        (showBottomBarSpace
            ? PageInsets.bottomNav(context)
            : PageInsets.bottomPlain(context));

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalInset =
        screenWidth > 960 ? (screenWidth - 900) / 2 : 0.0;

    Widget scroll = RepaintBoundary(
      child: CustomScrollView(
        controller: controller,
        physics:
            scrollPhysics ??
            const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: top,
              left: horizontalInset,
              right: horizontalInset,
            ),
            sliver: SliverList(delegate: SliverChildListDelegate(slivers)),
          ),
          SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
        ],
      ),
    );

    if (onRefresh != null) {
      scroll = RefreshIndicator.adaptive(
        onRefresh: onRefresh!,
        edgeOffset: top - 12,
        color: context.palette.accentBright,
        backgroundColor: context.palette.surface2,
        child: scroll,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: scroll),
          Positioned(
            top: 0,
            left: horizontalInset,
            right: horizontalInset,
            child: ColoredBox(
              color: context.palette.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: header,
                ),
              ),
            ),
          ),
          if (floatingAction != null)
            Positioned(
              left: 16 + horizontalInset,
              right: 16 + horizontalInset,
              bottom: showBottomBarSpace
                  ? MediaQuery.paddingOf(context).bottom + 94
                  : MediaQuery.paddingOf(context).bottom + 16,
              child: floatingAction!,
            ),
          if (footer != null)
            Positioned(
              left: horizontalInset,
              right: horizontalInset,
              bottom: 0,
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.blur = GlassTokens.blurLarge,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    assert(blur >= 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
      child: SizedBox(
        height: subtitle == null ? 40 : 48,
        child: Row(
          children: [
            if (onBack != null)
              AppIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 40,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onBack!();
                },
              )
            else
              ?leading,
            if (onBack != null || leading != null) const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: palette.text,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11.5,
                        height: 1.15,
                        fontWeight: FontWeight.w400,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.overline,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String overline;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overline.toUpperCase(),
                  style: AppTypography.overline(
                    color: context.palette.accentBright,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
  List<Widget> actions = const [],
  bool isScrollControlled = true,
  double maxHeightFactor = 0.88,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 580),
    barrierColor: Colors.black.withValues(alpha: 0.62),
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: Motion.sheetStyle(context),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          media.viewInsets.bottom + 12,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * maxHeightFactor,
          ),
          child: Material(
            color: sheetContext.palette.surface1,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: sheetContext.palette.border),
            ),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: sheetContext.palette.text.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AppSheetHeader(
                  title: title,
                  subtitle: subtitle,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: child,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: sheetContext.palette.border),
                  const SizedBox(height: 14),
                  ...actions,
                ],
              ],
            ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Подтвердить',
  String cancelLabel = 'Отмена',
  bool danger = false,
  required Future<void> Function() onConfirm,
}) async {
  var busy = false;
  await showGlassSheet<void>(
    context: context,
    title: title,
    child: StatefulBuilder(
      builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.palette.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: danger
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    loading: busy,
                    onPressed: () async {
                      setState(() => busy = true);
                      try {
                        await onConfirm();
                        if (context.mounted) Navigator.of(context).pop();
                      } finally {
                        if (context.mounted) setState(() => busy = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
