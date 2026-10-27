import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../domain/login_validation.dart';
import '../auth_controller.dart';
import 'login_field.dart';

/// Password recovery, presented as a glass sheet over the login screen.
///
/// Two states share one sheet: the request form and the confirmation.
/// The swap is a plain conditional build — the sheet's own entrance
/// already carries the motion, a second animation inside would fight it.
Future<void> showForgotPasswordSheet({
  required BuildContext context,
  required String initialEmail,
}) {
  return showGlassSheet<void>(
    context: context,
    title: 'Восстановление доступа',
    subtitle: 'Отправим ссылку для сброса пароля на рабочую почту.',
    child: _ForgotPasswordForm(initialEmail: initialEmail),
  );
}

class _ForgotPasswordForm extends ConsumerStatefulWidget {
  const _ForgotPasswordForm({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_ForgotPasswordForm> createState() =>
      _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<_ForgotPasswordForm> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final validation = LoginValidation.recoveryEmail(_email.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось отправить письмо');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           SurfaceIcon(
            icon: Icons.mark_email_read_outlined,
            size: 58,
            color: context.palette.success,
          ),
          const SizedBox(height: 18),
          Text(
            'Письмо отправлено',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Проверьте ${_email.text.trim()} и перейдите по ссылке из письма, чтобы задать новый пароль.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.palette.textTertiary, height: 1.5),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Готово',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        LoginField(
          controller: _email,
          label: 'Рабочая почта',
          hint: 'name@webbrand.tj',
          icon: Icons.mail_outline_rounded,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Отправить ссылку',
          loading: _busy,
          onPressed: _busy ? null : _send,
        ),
      ],
    );
  }
}
