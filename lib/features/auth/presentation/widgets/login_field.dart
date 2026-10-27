import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Sign-in field. The label and the value share one vertical center with
/// the leading icon. The border stays 1 px so focus never shifts the text.
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
    final palette = context.palette;
    final rim = hasError
        ? palette.danger
        : _focused
        ? palette.accent
        : palette.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: animate ? Motion.micro : Duration.zero,
          curve: Motion.easeOut,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: rim, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: hasError
                    ? palette.danger
                    : _focused
                    ? palette.accent
                    : palette.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: hasError
                            ? palette.danger
                            : _focused
                            ? palette.accent
                            : palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 20,
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
                        cursorHeight: 16,
                        cursorColor: palette.accent,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 15,
                          height: 1,
                          color: palette.text,
                        ),
                        strutStyle: const StrutStyle(
                          fontSize: 15,
                          height: 1,
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
                            fontSize: 15,
                            height: 1,
                            color: palette.textDisabled,
                          ),
                        ),
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 4),
                widget.suffix!,
              ],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 13, color: palette.danger),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 11.5,
                      height: 1.3,
                      color: palette.danger,
                    ),
                  ),
                ),
              ],
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
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: context.palette.textTertiary,
      ),
    );
  }
}
