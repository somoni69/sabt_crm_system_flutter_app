import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Sign-in text field with a focus-aware chrome.
///
/// The stock [InputDecoration] border can only swap colors instantly.
/// Here the whole plate is an [AnimatedContainer]: on focus the rim
/// warms to the accent, a soft glow blooms under the field and the
/// leading icon fills with colour and grows a touch. An error paints
/// the rim in danger and unfolds its message underneath — size and
/// opacity animated, never a layout jump cut.
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
    final accent = hasError ? context.palette.danger : context.palette.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: animate ? Motion.standard : Duration.zero,
          curve: Motion.easeOut,
          height: 66,
          decoration: BoxDecoration(
            color: context.palette.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? context.palette.danger.withValues(alpha: 0.75)
                  : _focused
                  ? context.palette.accent.withValues(alpha: 0.85)
                  : context.palette.borderSoft,
              width: _focused || hasError ? 1.3 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 15),
              AnimatedScale(
                scale: _focused && animate ? 1.12 : 1,
                duration: animate ? Motion.micro : Duration.zero,
                curve: Motion.easeOut,
                child: Icon(
                  widget.icon,
                  size: 19,
                  color: hasError
                      ? context.palette.danger
                      : _focused
                      ? context.palette.accentBright
                      : context.palette.textTertiary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: animate ? Motion.micro : Duration.zero,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: hasError
                            ? context.palette.danger
                            : _focused
                            ? context.palette.accentBright
                            : context.palette.textTertiary,
                      ),
                      child: Text(widget.label.toUpperCase()),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      obscureText: widget.obscureText,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      autofillHints: widget.autofillHints,
                      autocorrect: false,
                      enableSuggestions: !widget.obscureText,
                      maxLength: widget.maxLength,
                      inputFormatters: widget.inputFormatters,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 15,
                        height: 1.2,
                        color: context.palette.text,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 15,
                          color: context.palette.textDisabled,
                        ),
                      ),
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ],
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
              const SizedBox(width: 6),
            ],
          ),
        ),
        MotionSwap(
          alignment: Alignment.centerLeft,
          child: hasError
              ? Padding(
                  key: const ValueKey('field-error'),
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
                  key: ValueKey('field-clear'),
                  width: double.infinity,
                ),
        ),
      ],
    );
  }
}

/// Eye toggle for the password field: cross-fade with a quarter turn,
/// so showing a password feels like opening a shutter, not a swap.
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
    return IconButton(
      onPressed: onToggle,
      tooltip: obscure ? 'Показать пароль' : 'Скрыть пароль',
      icon: AnimatedSwitcher(
        duration: Motion.duration(context, Motion.micro),
        switchInCurve: Motion.easeOut,
        switchOutCurve: Motion.easeOut,
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween<double>(begin: 0.12, end: 0).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          key: ValueKey(obscure),
          size: 19,
          color: context.palette.textTertiary,
        ),
      ),
    );
  }
}
