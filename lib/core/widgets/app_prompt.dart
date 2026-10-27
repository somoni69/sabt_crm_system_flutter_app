import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_controls.dart';
import 'app_page.dart';
import 'app_surfaces.dart';

Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? subtitle,
  String hint = '',
  String actionLabel = 'Сохранить',
  int maxLines = 1,
  int maxLength = 2000,
  bool required = true,
  String? initial,
}) {
  return showGlassSheet<String>(
    context: context,
    title: title,
    subtitle: subtitle,
    child: _TextPromptForm(
      hint: hint,
      actionLabel: actionLabel,
      maxLines: maxLines,
      maxLength: maxLength,
      required: required,
      initial: initial,
    ),
  );
}

class _TextPromptForm extends StatefulWidget {
  const _TextPromptForm({
    required this.hint,
    required this.actionLabel,
    required this.maxLines,
    required this.maxLength,
    required this.required,
    this.initial,
  });

  final String hint;
  final String actionLabel;
  final int maxLines;
  final int maxLength;
  final bool required;
  final String? initial;

  @override
  State<_TextPromptForm> createState() => _TextPromptFormState();
}

class _TextPromptFormState extends State<_TextPromptForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (widget.required && value.isEmpty) {
      setState(() => _error = 'Заполните поле');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: widget.maxLines == 1 ? 1 : 3,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14.5,
            height: 1.45,
            color: context.palette.text,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: widget.maxLength > 500 ? null : '',
            counterStyle:  TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 10,
              color: context.palette.textDisabled,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: widget.actionLabel,
          onPressed: _submit,
        ),
      ],
    );
  }
}
