import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/brand_mark.dart';
import '../../../core/design/motion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../domain/login_validation.dart';
import 'auth_controller.dart';
import 'widgets/forgot_password_sheet.dart';
import 'widgets/login_button.dart';
import 'widgets/login_field.dart';
import 'widgets/otp_field.dart';
import 'widgets/shake.dart';

/// Вход в том же виде, что экран авторизации на вебе: WeBrand,
/// карточка с полями и стальная кнопка.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _obscure = true;
  bool _needsTwoFactor = false;
  Brightness? _localBrightnessOverride;
  LoginButtonPhase _phase = LoginButtonPhase.idle;
  String? _error;
  String? _emailError;
  String? _passwordError;
  String? _codeError;
  int _shakeSignal = 0;

  bool get _busy => _phase == LoginButtonPhase.loading;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleTheme(BuildContext context) async {
    HapticFeedback.selectionClick();
    final currentlyDark = Theme.of(context).brightness == Brightness.dark;
    final nextMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    try {
      await ref.read(themeModeProvider.notifier).set(nextMode);
      if (mounted) setState(() => _localBrightnessOverride = null);
    } catch (_) {
      // Fallback when pumped in isolated widget tests without
      // dependenciesProvider overridden.
      if (mounted) {
        setState(() {
          _localBrightnessOverride =
              currentlyDark ? Brightness.light : Brightness.dark;
        });
      }
    }
  }

  void _reject(String message) {
    setState(() {
      _error = message;
      _shakeSignal++;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _submit() async {
    if (_phase != LoginButtonPhase.idle) return;

    final emailError = LoginValidation.login(_email.text);
    final passwordError = LoginValidation.password(_password.text);
    final codeError = _needsTwoFactor
        ? LoginValidation.twoFactorCode(_code.text)
        : null;

    if (emailError != null || passwordError != null || codeError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _codeError = codeError;
        _error = null;
        _shakeSignal++;
      });
      HapticFeedback.mediumImpact();
      if (emailError != null) {
        _emailFocus.requestFocus();
      } else if (passwordError != null) {
        _passwordFocus.requestFocus();
      } else {
        _codeFocus.requestFocus();
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _phase = LoginButtonPhase.loading;
      _error = null;
      _emailError = null;
      _passwordError = null;
      _codeError = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: LoginValidation.normalizeLogin(_email.text),
            password: _password.text,
            twoFactorCode: _needsTwoFactor
                ? LoginValidation.normalizeCode(_code.text)
                : null,
          );
      if (!mounted) return;
      setState(() => _phase = LoginButtonPhase.success);
      HapticFeedback.lightImpact();
    } on TwoFactorRequiredException {
      if (!mounted) return;
      setState(() {
        _needsTwoFactor = true;
        _phase = LoginButtonPhase.idle;
        _error = null;
      });
      HapticFeedback.selectionClick();
      _codeFocus.requestFocus();
    } on AccountBlockedException catch (error) {
      if (!mounted) return;
      setState(() => _phase = LoginButtonPhase.idle);
      _reject(error.message);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _phase = LoginButtonPhase.idle);
      _reject(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = LoginButtonPhase.idle);
      _reject('Не удалось войти. Проверьте соединение и повторите.');
    }
  }

  void _forgotPassword(BuildContext innerContext) {
    showForgotPasswordSheet(
      context: innerContext,
      initialEmail: _email.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overrideBrightness = _localBrightnessOverride;
    if (overrideBrightness != null) {
      return Theme(
        data: overrideBrightness == Brightness.dark
            ? AppTheme.dark
            : AppTheme.light,
        child: Builder(builder: _buildScreen),
      );
    }
    return _buildScreen(context);
  }

  Widget _buildScreen(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const WeBrandWordmark(fontSize: 34),
                  const SizedBox(height: 22),
                  Shake(
                    signal: _shakeSignal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        color: palette.surface1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _needsTwoFactor ? 'Подтвердите вход' : 'Войти',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          if (_needsTwoFactor) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Введите шестизначный код из приложения-аутентификатора.',
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 13,
                                height: 1.35,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _buildForm(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '© ${DateTime.now().year} WeBrand CRM',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ThemeTogglePill(
                    isDark: palette.isDark,
                    onTap: () => _toggleTheme(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MotionSwap(
          animateSize: true,
          child: _error == null
              ? const SizedBox(
                  key: ValueKey('login-clear'),
                  width: double.infinity,
                )
              : Padding(
                  key: const ValueKey('login-error'),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InlineError(message: _error!, compact: true),
                ),
        ),
        LoginField(
          controller: _email,
          focusNode: _emailFocus,
          label: 'Логин или email',
          hint: 'логин или email',
          icon: Icons.alternate_email_rounded,
          enabled: !_busy && _phase != LoginButtonPhase.success,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: 14),
        LoginField(
          controller: _password,
          focusNode: _passwordFocus,
          label: 'Пароль',
          hint: 'Ваш пароль',
          icon: Icons.lock_outline_rounded,
          enabled: !_busy && _phase != LoginButtonPhase.success,
          errorText: _passwordError,
          obscureText: _obscure,
          textInputAction: _needsTwoFactor
              ? TextInputAction.next
              : TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          headerTrailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : () => _forgotPassword(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Text(
                'Забыли пароль?',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.brandPurple,
                ),
              ),
            ),
          ),
          suffix: PasswordVisibilityToggle(
            obscure: _obscure,
            onToggle: () => setState(() => _obscure = !_obscure),
          ),
          onChanged: (_) {
            if (_passwordError != null) setState(() => _passwordError = null);
          },
          onSubmitted: (_) {
            if (_needsTwoFactor) {
              _codeFocus.requestFocus();
            } else {
              unawaited(_submit());
            }
          },
        ),
        MotionSwap(
          animateSize: true,
          child: _needsTwoFactor
              ? Padding(
                  key: const ValueKey('otp-block'),
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Код из приложения',
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _busy
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _needsTwoFactor = false;
                                      _code.clear();
                                      _codeError = null;
                                    });
                                  },
                            child: Text(
                              'Сменить аккаунт',
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OtpField(
                        controller: _code,
                        focusNode: _codeFocus,
                        enabled: !_busy,
                        errorText: _codeError,
                        onCompleted: (_) => unawaited(_submit()),
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  key: ValueKey('otp-hidden'),
                  width: double.infinity,
                ),
        ),
        const SizedBox(height: 18),
        LoginButton(
          phase: _phase,
          label: _needsTwoFactor ? 'Подтвердить' : 'Войти',
          onPressed: _phase == LoginButtonPhase.idle ? _submit : null,
        ),
      ],
    );
  }
}

class _ThemeTogglePill extends StatelessWidget {
  const _ThemeTogglePill({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lipColor = isDark
        ? const Color(0xFF05070C)
        : const Color(0xFFD4DBEC);

    return PressableScale(
      onTap: onTap,
      haptic: false,
      child: Semantics(
        button: true,
        label: isDark ? 'Включить светлую тему' : 'Включить тёмную тему',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: palette.surface1,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: lipColor,
                offset: const Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 15,
                color: palette.brandPurple,
              ),
              const SizedBox(width: 6),
              Text(
                isDark ? 'Светлая' : 'Тёмная',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
