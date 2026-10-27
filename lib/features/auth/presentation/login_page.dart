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
import '../../../core/widgets/app_surfaces.dart';
import '../domain/login_validation.dart';
import 'auth_controller.dart';
import 'widgets/animated_brand_mark.dart';
import 'widgets/forgot_password_sheet.dart';
import 'widgets/login_background.dart';
import 'widgets/login_button.dart';
import 'widgets/login_field.dart';
import 'widgets/otp_field.dart';
import 'widgets/shake.dart';

/// Sign-in screen.
///
/// Composition only: the page owns the form state and the submit
/// choreography, every visual primitive lives in its own widget under
/// `widgets/` (background, brand mark, fields, OTP cells, button).
///
/// Motion contract:
/// * one [Motion.entrance] controller drives the whole arrival —
///   background, mark, wordmark, card and footer take staggered slices
///   of it via [StaggeredEntrance], so there is exactly one ticker and
///   nothing appears before the first frame;
/// * a rejected attempt shakes the card once and unfolds the reason;
/// * the button morphs idle → loading → success, and the router's own
///   transition carries the user into the workspace from there;
/// * reduced motion collapses every duration to zero.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _codeFocus = FocusNode();

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  bool _obscure = true;
  bool _needsTwoFactor = false;
  LoginButtonPhase _phase = LoginButtonPhase.idle;
  String? _error;
  String? _emailError;
  String? _passwordError;
  String? _codeError;
  int _shakeSignal = 0;

  bool get _busy => _phase == LoginButtonPhase.loading;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.allowed(context) && _entrance.value != 1) {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
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
      // The router redirects on the new auth state; the success morph
      // is what the user sees while that transition runs.
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

  void _forgotPassword() {
    showForgotPasswordSheet(context: context, initialEmail: _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final animate = Motion.allowed(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: LoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand block collapses gracefully when the
                      // keyboard claims the screen: the mark shrinks,
                      // the wordmark fades out and its height snaps —
                      // layout is never animated (see MotionSwap).
                      Column(
                        children: [
                          StaggeredEntrance(
                            animation: _entrance,
                            begin: 0,
                            end: 0.45,
                            dy: 10,
                            child: AnimatedScale(
                              scale: keyboardOpen ? 0.68 : 1,
                              duration: animate
                                  ? Motion.standard
                                  : Duration.zero,
                              curve: Motion.easeOut,
                              child: const AnimatedBrandMark(
                                size: 84,
                                playEntrance: false,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: keyboardOpen ? 0 : 1,
                            duration: animate ? Motion.micro : Duration.zero,
                            child: keyboardOpen
                                ? const SizedBox(width: double.infinity)
                                : Column(
                                    children: [
                                      const SizedBox(height: 6),
                                      StaggeredEntrance(
                                        animation: _entrance,
                                        begin: 0.10,
                                        end: 0.55,
                                        child: const Center(
                                          child: SabtWordmark(fontSize: 36),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      StaggeredEntrance(
                                        animation: _entrance,
                                        begin: 0.18,
                                        end: 0.60,
                                        child: Center(
                                          child: Text(
                                            'Рабочее пространство WeBrand',
                                            style: TextStyle(
                                              fontFamily: AppTypography.family,
                                              fontSize: 12,
                                              letterSpacing: 0.15,
                                              color: context.palette.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.22,
                        end: 0.78,
                        dy: 16,
                        scaleFrom: 1,
                        child: Shake(
                          signal: _shakeSignal,
                          child: GlassSurface(
                            radius: 28,
                            blur: GlassTokens.blurXl,
                            strong: true,
                            glow: true,
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                            child: _buildForm(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.62,
                        end: 1,
                        dy: 8,
                        scaleFrom: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: context.palette.textDisabled,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sabt CRM · данные под защитой',
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 10.5,
                                color: context.palette.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _needsTwoFactor ? 'ПОДТВЕРЖДЕНИЕ' : 'ВХОД',
              style: AppTypography.overline(color: context.palette.accentBright),
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
        MotionSwap(
          alignment: Alignment.centerLeft,
          child: Column(
            key: ValueKey(_needsTwoFactor),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _needsTwoFactor ? 'Подтвердите вход' : 'С возвращением',
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 26,
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: context.palette.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _needsTwoFactor
                    ? 'Введите шестизначный код из приложения-аутентификатора.'
                    : 'Войдите, чтобы продолжить работу с задачами, контентом и клиентами.',
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12.5,
                  height: 1.45,
                  color: context.palette.textTertiary,
                ),
              ),
            ],
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
                  child: InlineError(message: _error!, compact: true),
                ),
        ),
        LoginField(
          controller: _email,
          focusNode: _emailFocus,
          label: 'Логин или почта',
          hint: 'name@webbrand.tj',
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
        const SizedBox(height: 12),
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
          child: _needsTwoFactor
              ? Padding(
                  key: const ValueKey('otp-block'),
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'КОД ИЗ ПРИЛОЖЕНИЯ',
                        style: AppTypography.overline(
                          color: context.palette.textTertiary,
                        ),
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Сессия защищена и хранится в keychain устройства.',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 10.5,
                  height: 1.35,
                  color: context.palette.textDisabled,
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
        LoginButton(
          phase: _phase,
          label: _needsTwoFactor ? 'Подтвердить' : 'Войти',
          onPressed: _phase == LoginButtonPhase.idle ? _submit : null,
        ),
      ],
    );
  }
}
