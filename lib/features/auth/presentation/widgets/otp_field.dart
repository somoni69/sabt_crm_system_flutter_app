import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Six-cell one-time-code field.
///
/// A single invisible [TextField] owns the keyboard, autofill and paste;
/// the visible cells are a pure projection of its value. That gives the
/// user a segmented, app-grade control (tap anywhere focuses, pasting a
/// code fills every cell, the sixth digit fires [onCompleted]) while the
/// platform still sees one ordinary text input — no six-controller
/// focus juggling, no lost characters.
///
/// The active cell carries a blinking caret and an accent rim; filled
/// cells settle onto a lifted surface. All of it is transform/opacity
/// and border colour — no layout animation.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.errorText,
    this.onCompleted,
    this.length = 6,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onCompleted;
  final int length;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;
  bool _focused = false;

  late final AnimationController _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocus);
    widget.controller.addListener(_handleValue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.allowed(context)) {
      if (!_caret.isAnimating) _caret.repeat(reverse: true);
    } else {
      _caret.stop();
      _caret.value = 0;
    }
  }

  void _handleFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  void _handleValue() {
    if (!mounted) return;
    setState(() {});
    final value = widget.controller.text;
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    widget.controller.removeListener(_handleValue);
    if (_ownsFocusNode) _focusNode.dispose();
    _caret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = Motion.allowed(context);
    final value = widget.controller.text;
    final hasError = widget.errorText != null;

    return Semantics(
      label: 'Код двухфакторной аутентификации',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _focusNode.requestFocus : null,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _OtpCell(
                          char: i < value.length ? value[i] : null,
                          active: _focused && i == value.length,
                          filled: i < value.length,
                          hasError: hasError,
                          caret: _caret,
                          animate: animate,
                        ),
                      ),
                    ],
                  ],
                ),
                // The real input: transparent, but focusable, tappable
                // and paste-aware. It covers the cells exactly.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: widget.length,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      showCursor: false,
                      enableInteractiveSelection: false,
                      style: const TextStyle(color: Colors.transparent),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          MotionSwap(
            child: hasError
                ? Padding(
                    key: const ValueKey('otp-error'),
                    padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 13,
                          color: context.palette.danger,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.errorText!,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 11.5,
                              height: 1.3,
                              color: context.palette.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('otp-clear'),
                    width: double.infinity,
                  ),
          ),
        ],
      ),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.char,
    required this.active,
    required this.filled,
    required this.hasError,
    required this.caret,
    required this.animate,
  });

  final String? char;
  final bool active;
  final bool filled;
  final bool hasError;
  final AnimationController caret;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animate ? Motion.micro : Duration.zero,
      curve: Motion.easeOut,
      height: 58,
      decoration: BoxDecoration(
        color: filled ? context.palette.surface3 : context.palette.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? context.palette.danger.withValues(alpha: 0.75)
              : active
              ? context.palette.accent.withValues(alpha: 0.9)
              : filled
              ? context.palette.borderStrong
              : context.palette.borderSoft,
          width: active || hasError ? 1.3 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: context.palette.accent.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: animate ? Motion.micro : Duration.zero,
          switchInCurve: Motion.easeOut,
          switchOutCurve: Motion.easeOut,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: char != null
              ? Text(
                  char!,
                  key: ValueKey('otp-$char'),
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
                    fontFeatures: AppTypography.tabular,
                  ),
                )
              : active
              ? AnimatedBuilder(
                  key: const ValueKey('otp-caret'),
                  animation: caret,
                  builder: (context, _) {
                    final blink = animate
                        ? (caret.value < 0.55 ? 1.0 : 0.15)
                        : 1.0;
                    return Opacity(
                      opacity: blink,
                      child: Container(
                        width: 2,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.palette.accentBright,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  key: const ValueKey('otp-dot'),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.palette.textDisabled,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}
