import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_env.dart';
import '../../../core/design/brand_mark.dart';
import '../../../core/design/glass_surface.dart';
import '../../../core/design/glass_tokens.dart';
import '../../../core/design/motion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../presentation/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _passwordFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  bool _needsTwoFactor = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _passwordFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите логин и пароль');
      return;
    }
    if (_needsTwoFactor && _code.text.trim().isEmpty) {
      setState(() => _error = 'Введите код двухфакторной аутентификации');
      _codeFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: email,
            password: password,
            twoFactorCode: _needsTwoFactor ? _code.text : null,
          );
    } on TwoFactorRequiredException {
      if (!mounted) return;
      setState(() {
        _needsTwoFactor = true;
        _busy = false;
        _error = null;
      });
      _codeFocus.requestFocus();
      return;
    } on AccountBlockedException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось войти. Проверьте соединение и повторите.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    showGlassSheet<void>(
      context: context,
      title: 'Восстановление доступа',
      subtitle: 'Отправим ссылку для сброса пароля на рабочую почту.',
      child: _ForgotPasswordForm(initialEmail: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SabtGlassMark(size: 78)),
                  const SizedBox(height: 16),
                  const Center(child: SabtWordmark(fontSize: 36)),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Рабочее пространство WeBrand',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        letterSpacing: 0.15,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GlassSurface(
                    radius: 28,
                    blur: GlassTokens.blurXl,
                    strong: true,
                    glow: true,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ВХОД',
                              style: AppTypography.overline(
                                color: AppColors.accentBright,
                              ),
                            ),
                            const Spacer(),
                            if (AppEnv.isWeb)
                              const AppChip(
                                label: 'Web',
                                tone: ChipTone.info,
                                icon: Icons.language_rounded,
                                compact: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _needsTwoFactor
                              ? 'Подтвердите вход'
                              : 'С возвращением',
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 26,
                            height: 1.12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _needsTwoFactor
                              ? 'Введите шестизначный код из приложения-аутентификатора.'
                              : 'Войдите, чтобы продолжить работу с задачами, контентом и клиентами.',
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        MotionSwap(
                          child: _error == null
                              ? const SizedBox(
                                  key: ValueKey('login-clear'),
                                  width: double.infinity,
                                )
                              : Padding(
                                  key: const ValueKey('login-error'),
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: InlineError(
                                    message: _error!,
                                    compact: true,
                                  ),
                                ),
                        ),
                        TextField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Логин или почта',
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              size: 19,
                            ),
                          ),
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_busy,
                          obscureText: _obscure,
                          textInputAction: _needsTwoFactor
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Пароль',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 19,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              tooltip: _obscure
                                  ? 'Показать пароль'
                                  : 'Скрыть пароль',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 19,
                              ),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (_needsTwoFactor) {
                              _codeFocus.requestFocus();
                            } else {
                              _submit();
                            }
                          },
                        ),
                        MotionSwap(
                          child: !_needsTwoFactor
                              ? const SizedBox(
                                  key: ValueKey('no-2fa'),
                                  width: double.infinity,
                                )
                              : Padding(
                                  key: const ValueKey('2fa'),
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextField(
                                    controller: _code,
                                    focusNode: _codeFocus,
                                    enabled: !_busy,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                      fontFamily: AppTypography.family,
                                      fontSize: 20,
                                      letterSpacing: 8,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                      fontFeatures: AppTypography.tabular,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '000000',
                                      counterText: '',
                                      prefixIcon: Icon(
                                        Icons.shield_outlined,
                                        size: 19,
                                      ),
                                    ),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Сессия защищена и хранится в keychain устройства.',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 10.5,
                                  height: 1.35,
                                  color: AppColors.textDisabled,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _forgotPassword,
                              child: const Text('Забыли пароль?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: _needsTwoFactor ? 'Подтвердить' : 'Войти',
                          icon: Icons.arrow_forward_rounded,
                          loading: _busy,
                          onPressed: _busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sabt CRM · данные под защитой',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10.5,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Укажите рабочую почту');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
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
          const SurfaceIcon(
            icon: Icons.mark_email_read_outlined,
            size: 58,
            color: AppColors.success,
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
                ?.copyWith(color: AppColors.textTertiary, height: 1.5),
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
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            color: AppColors.text,
          ),
          decoration: const InputDecoration(
            hintText: 'name@webbrand.tj',
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
          ),
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
