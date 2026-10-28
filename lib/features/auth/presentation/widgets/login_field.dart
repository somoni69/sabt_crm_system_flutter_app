import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Tactile sign-in input field.
///
/// Follows the native-craft anti-slop standard:
/// * clean sentence-case label sits outside the input plate (no tiny
///   all-caps kicker crammed inside the text box);
/// * crisp 1.4 px border with a physical 2 px bottom lip at rest and a
///   soft brand focus ring when active;
/// * leading icon sits inside a structured squircle tile.
class LoginField extends StatefulWidget {
  const LoginField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.suffix,
    this.headerTrailing,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? suffix;
  final Widget? headerTrailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<LoginField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = Motion.allowed(context);
    final hasError = widget.errorText != null;
    final palette = context.palette;

    final borderColor = hasError
        ? palette.danger
        : _focused
        ? palette.brandPurple
        : palette.border;

    final lipColor = hasError
        ? palette.danger.withValues(alpha: 0.35)
        : _focused
        ? palette.brandPurple.withValues(alpha: 0.45)
        : (palette.isDark ? const Color(0xFF06080E) : const Color(0xFFD6DCEC));

    final iconColor = hasError
        ? palette.danger
        : _focused
        ? palette.brandPurple
        : palette.textSecondary;

    final iconBg = hasError
        ? palette.danger.withValues(alpha: 0.12)
        : _focused
        ? palette.brandPurple.withValues(alpha: 0.14)
        : palette.surface2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: hasError
                        ? palette.danger
                        : _focused
                        ? palette.text
                        : palette.textSecondary,
                  ),
                ),
              ),
              if (widget.headerTrailing != null) widget.headerTrailing!,
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _focusNode.requestFocus : null,
          child: AnimatedContainer(
            duration: animate ? Motion.micro : Duration.zero,
            curve: Motion.easeOut,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _focused ? palette.surface1 : palette.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: _focused || hasError ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: lipColor,
                  offset: const Offset(0, 2.0),
                  blurRadius: 0,
                ),
                if (_focused)
                  BoxShadow(
                    color: (hasError ? palette.danger : palette.brandPurple)
                        .withValues(alpha: 0.12),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: animate ? Motion.micro : Duration.zero,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textAlignVertical: TextAlignVertical.center,
                    autofillHints: widget.autofillHints,
                    autocorrect: false,
                    enableSuggestions: !widget.obscureText,
                    maxLength: widget.maxLength,
                    inputFormatters: widget.inputFormatters,
                    cursorHeight: 18,
                    cursorColor: palette.brandPurple,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                    ),
                    strutStyle: const StrutStyle(
                      fontSize: 15,
                      height: 1.2,
                      forceStrutHeight: true,
                      leading: 0,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      counterText: '',
                      hintText: widget.hint,
                      hintStyle: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14.5,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: palette.textDisabled,
                      ),
                    ),
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                  ),
                ),
                if (widget.suffix != null) ...[
                  const SizedBox(width: 4),
                  widget.suffix!,
                ],
              ],
            ),
          ),
        ),
        MotionSwap(
          duration: Motion.micro,
          scale: false,
          animateSize: true,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  key: ValueKey(widget.errorText),
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 13.5,
                        color: palette.danger,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: palette.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  key: ValueKey('no-field-error'),
                  width: double.infinity,
                ),
        ),
      ],
    );
  }
}

/// Eye toggle for the password field with tactile selection feedback.
class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    super.key,
    required this.obscure,
    required this.onToggle,
  });

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      tooltip: obscure ? 'Показать пароль' : 'Скрыть пароль',
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 19,
        color: palette.textTertiary,
      ),
    );
  }
}
