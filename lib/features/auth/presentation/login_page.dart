import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_env.dart';
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
import 'widgets/login_background.dart';
import 'widgets/login_button.dart';
import 'widgets/login_field.dart';
import 'widgets/login_hero_stage.dart';
import 'widgets/otp_field.dart';
import 'widgets/shake.dart';

/// Sign-in screen crafted to the Appllama / native iOS benchmark bar.
///
/// Visual & interaction architecture:
/// * Top bar carries the brand wordmark and a tactile theme switcher
///   pill so the user can move between Porcelain Light and Obsidian
///   Dark right from the welcome screen;
/// * [LoginHeroStage] frames the focal Sabt mark with floating peripheral
///   status stickers and three tilted tactile pillar tiles ("Задачи.",
///   "Контент.", "Клиенты.") that preview live workspace cards on tap;
/// * The sign-in form sits on a grounded tactile card with a physical
///   3.5 px bottom lip — zero glassmorphic soup, zero uppercase eyebrow
///   kickers, sentence-case external field labels;
/// * One shared [_entrance] controller drives the staggered arrival.
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
  Brightness? _localBrightnessOverride;
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final palette = context.palette;
    final lipColor = palette.isDark
        ? const Color(0xFF05070C)
        : const Color(0xFFD2DAEB);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: LoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  keyboardOpen ? 12 : 16,
                  20,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top utility bar: wordmark + tactile theme toggle.
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.0,
                        end: 0.38,
                        dy: 8,
                        child: Row(
                          children: [
                            const SabtWordmark(fontSize: 25),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surface1,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text(
                                'WeBrand',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (AppEnv.isWeb) ...[
                              const AppChip(
                                label: 'Web',
                                tone: ChipTone.info,
                                icon: Icons.language_rounded,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                            ],
                            _ThemeTogglePill(
                              isDark: palette.isDark,
                              onTap: () => _toggleTheme(context),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: keyboardOpen ? 12 : 20),

                      // 2. Spatial hero stage with floating stickers,
                      //    3 tilted pillar tiles, and live preview card.
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.08,
                        end: 0.52,
                        dy: 12,
                        child: LoginHeroStage(
                          compact: keyboardOpen || _needsTwoFactor,
                        ),
                      ),
                      SizedBox(height: keyboardOpen ? 12 : 18),

                      // 3. Editorial heading & subtitle (no uppercase kicker).
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.16,
                        end: 0.62,
                        dy: 12,
                        child: MotionSwap(
                          alignment: Alignment.center,
                          child: Column(
                            key: ValueKey(_needsTwoFactor),
                            children: [
                              Text(
                                _needsTwoFactor
                                    ? 'Подтвердите вход'
                                    : 'С возвращением',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: keyboardOpen ? 24 : 28,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.7,
                                  color: palette.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  _needsTwoFactor
                                      ? 'Введите шестизначный код из приложения-аутентификатора.'
                                      : 'Войдите, чтобы продолжить работу с задачами, контентом и клиентами.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTypography.family,
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: keyboardOpen ? 14 : 18),

                      // 4. Grounded tactile form sheet with physical 3D lip.
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.24,
                        end: 0.82,
                        dy: 16,
                        scaleFrom: 1,
                        child: Shake(
                          signal: _shakeSignal,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            decoration: BoxDecoration(
                              color: palette.surface1,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: palette.border,
                                width: 1.3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: lipColor,
                                  offset: const Offset(0, 3.5),
                                  blurRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: palette.isDark ? 0.34 : 0.06,
                                  ),
                                  offset: const Offset(0, 14),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                            child: _buildForm(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Single understated security badge at the foot.
                      StaggeredEntrance(
                        animation: _entrance,
                        begin: 0.60,
                        end: 1.0,
                        dy: 8,
                        scaleFrom: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 13,
                              color: palette.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Защищённая сессия · Sabt Keychain',
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: palette.textTertiary,
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
