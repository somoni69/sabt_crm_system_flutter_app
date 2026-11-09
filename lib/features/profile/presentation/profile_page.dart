import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_prompt.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_work_section.dart';

final _sessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final raw = await ref.watch(authRepositoryProvider).sessions();
      return raw.map(asMap).whereType<Map<String, dynamic>>().toList();
    });

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _uploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      await ref
          .read(dependenciesProvider)
          .api
          .uploadBytes(
            '/users/me/avatar',
            field: 'avatar',
            bytes: bytes,
            filename: picked.name,
            method: 'PATCH',
          );
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            const AppBanner(
              title: 'Фото обновлено',
              message: 'Новый аватар уже виден команде.',
              tone: BannerTone.success,
            ),
          );
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Не удалось загрузить изображение');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showError(String message) {
    ref
        .read(dependenciesProvider)
        .banners
        .show(
          AppBanner(title: 'Ошибка', message: message, tone: BannerTone.danger),
        );
  }

  Future<void> _changePassword() async {
    final ok = await showGlassSheet<bool>(
      context: context,
      title: 'Сменить пароль',
      subtitle: 'Пароль должен содержать не меньше 6 символов.',
      child: const _PasswordForm(),
    );
    if (ok == true && mounted) {
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            const AppBanner(
              title: 'Пароль изменён',
              message: 'Используйте новый пароль при следующем входе.',
              tone: BannerTone.success,
            ),
          );
    }
  }

  Future<void> _enableTwoFactor() async {
    final enabled = await showGlassSheet<bool>(
      context: context,
      title: 'Двухфакторная защита',
      subtitle: 'Отсканируйте QR-код в приложении-аутентификаторе.',
      child: const _TwoFactorSetup(),
    );
    if (enabled == true && mounted) {
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            const AppBanner(
              title: '2FA включена',
              message: 'Теперь при входе потребуется код из аутентификатора.',
              tone: BannerTone.success,
            ),
          );
    }
  }

  Future<void> _disableTwoFactor() async {
    final code = await showTextPrompt(
      context,
      title: 'Отключить 2FA',
      subtitle: 'Введите текущий код из приложения-аутентификатора.',
      hint: '6-значный код',
      actionLabel: 'Отключить',
      maxLength: 8,
    );
    if (code == null || code.trim().length < 6) return;
    try {
      await ref.read(authRepositoryProvider).disableTwoFactor(code.trim());
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            const AppBanner(
              title: '2FA отключена',
              message: 'Двухфакторная защита больше не действует.',
              tone: BannerTone.warning,
            ),
          );
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _openSessions() {
    showGlassSheet<void>(
      context: context,
      title: 'История входов',
      subtitle: 'Сессии за последние 7 дней.',
      maxHeightFactor: 0.7,
      child: const _SessionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final permissions = ref.watch(permissionsProvider);
    final sessions = ref.watch(_sessionsProvider).value ?? const [];
    final totalHours = sessions.fold<double>(0, (sum, session) {
      final raw = session['durationHours'];
      final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
      return sum + value;
    });

    if (user == null) {
      return const AppPage(
        showBottomBarSpace: false,
        header: AppHeader(title: 'Профиль'),
        slivers: [SkeletonBox(height: 220, radius: 24)],
      );
    }

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: 'Профиль',
        subtitle: user.roleLabel,
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.settings_outlined,
            size: 40,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHero(
                user: user,
                uploading: _uploadingAvatar,
                onAvatarTap: _pickAvatar,
              ),
              const SizedBox(height: 18),
              ProfileWorkSection(user: user),
              const SectionHeader(overline: 'АККАУНТ', title: 'Данные профиля'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Почта',
                      value: user.email,
                      icon: Icons.mail_outline_rounded,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Роль',
                      value: user.roleLabel,
                      icon: Icons.shield_outlined,
                    ),
                    if (user.secondaryRole != null) ...[
                      Divider(height: 1, color: context.palette.borderSoft),
                      KeyValueRow(
                        label: 'Доп. роль',
                        value: _roleLabel(user.secondaryRole!),
                        icon: Icons.shield_moon_outlined,
                      ),
                    ],
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Должность',
                      value: user.displayPosition,
                      icon: Icons.badge_outlined,
                    ),
                    if (user.department != null) ...[
                      Divider(height: 1, color: context.palette.borderSoft),
                      KeyValueRow(
                        label: 'Отдел',
                        value: user.department!,
                        icon: Icons.apartment_rounded,
                      ),
                    ],
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Права доступа',
                      value: '${permissions.length} разрешений',
                      icon: Icons.key_outlined,
                    ),
                    if (user.isSubAdmin) ...[
                      Divider(height: 1, color: context.palette.borderSoft),
                      KeyValueRow(
                        label: 'Статус',
                        value: 'Сооснователь',
                        icon: Icons.workspace_premium_outlined,
                        valueColor: context.palette.accentBright,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(
                overline: 'БЕЗОПАСНОСТЬ',
                title: 'Защита входа',
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                radius: 20,
                child: Column(
                  children: [
                    _SecurityRow(
                      icon: Icons.password_rounded,
                      color: context.palette.accentBright,
                      title: 'Пароль',
                      subtitle: 'Смените пароль в любой момент',
                      onTap: _changePassword,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    _SecurityRow(
                      icon: Icons.verified_user_outlined,
                      color: user.twoFactorEnabled
                          ? context.palette.success
                          : context.palette.warning,
                      title: 'Двухфакторная аутентификация',
                      subtitle: user.twoFactorEnabled
                          ? 'Включена · защита кодом'
                          : 'Не включена · рекомендуем',
                      trailing: AppChip(
                        label: user.twoFactorEnabled ? 'Вкл' : 'Выкл',
                        tone: user.twoFactorEnabled
                            ? ChipTone.success
                            : ChipTone.warning,
                        compact: true,
                      ),
                      onTap: user.twoFactorEnabled
                          ? _disableTwoFactor
                          : _enableTwoFactor,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    _SecurityRow(
                      icon: Icons.devices_outlined,
                      color: context.palette.ice,
                      title: 'Сессии',
                      subtitle: sessions.isEmpty
                          ? 'История появится после первого входа'
                          : '${sessions.length} сессий · ${Money.hours(totalHours)}',
                      onTap: _openSessions,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AccentNote(
                icon: Icons.info_outline_rounded,
                text: 'Профиль синхронизирован с Sabt CRM для браузера. Фото и пароль меняются сразу для всех устройств.',
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ],
    );
  }

  static String _roleLabel(String role) {
    return switch (role) {
      'admin' => 'Администратор',
      'founder' => 'Основатель',
      'smm_director' => 'Руководитель SMM',
      'smm_specialist' => 'SMM специалист',
      'designer' => 'Дизайнер',
      'sales_manager_smm' => 'Менеджер продаж (SMM)',
      'sales_manager_dev' => 'Менеджер продаж (Разработка)',
      'dev_director' => 'Руководитель разработки',
      'pm_dev' => 'Проект-менеджер',
      'developer' => 'Разработчик',
      'videographer' => 'Видеограф',
      'video_editor' => 'Монтажёр',
      'producer' => 'Продюсер',
      'targetologist' => 'Таргетолог',
      'stories_checker' => 'Проверяющий сторис',
      'employee' => 'Сотрудник',
      _ => role,
    };
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.uploading,
    required this.onAvatarTap,
  });

  final dynamic user;
  final bool uploading;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return AppHeroCard(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      radius: 26,
      child: Column(
        children: [
          GestureDetector(
            onTap: uploading ? null : onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  name: user.name as String,
                  avatar: user.avatar as String?,
                  size: 92,
                  ring: true,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: context.palette.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.palette.surface1,
                        width: 2.5,
                      ),
                    ),
                    child: uploading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.photo_camera_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            user.name as String,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            (user.email as String),
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              color: context.palette.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              AppChip(
                label: user.combinedRoleLabel as String,
                tone: ChipTone.accent,
                compact: true,
              ),
              if ((user.department as String?) != null)
                AppChip(
                  label: user.department as String,
                  tone: ChipTone.info,
                  compact: true,
                ),
              AppChip(
                label: (user.twoFactorEnabled as bool) ? '2FA' : 'Без 2FA',
                tone: (user.twoFactorEnabled as bool)
                    ? ChipTone.success
                    : ChipTone.neutral,
                icon: Icons.shield_outlined,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          children: [
            SurfaceIcon(icon: icon, color: color, size: 36, radius: 12),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10.5,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty || _new.text.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    if (_new.text.length < 6) {
      setState(() => _error = 'Новый пароль слишком короткий');
      return;
    }
    if (_new.text != _repeat.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(oldPassword: _old.text, newPassword: _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось изменить пароль');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        _passwordField(
          controller: _old,
          hint: 'Текущий пароль',
          action: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        _passwordField(
          controller: _new,
          hint: 'Новый пароль',
          action: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        _passwordField(
          controller: _repeat,
          hint: 'Повторите новый пароль',
          action: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Изменить пароль',
          icon: Icons.lock_reset_rounded,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required TextInputAction action,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: true,
      textInputAction: action,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 14.5,
        color: context.palette.text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
      ),
    );
  }
}

class _TwoFactorSetup extends ConsumerStatefulWidget {
  const _TwoFactorSetup();

  @override
  ConsumerState<_TwoFactorSetup> createState() => _TwoFactorSetupState();
}

class _TwoFactorSetupState extends ConsumerState<_TwoFactorSetup> {
  final _code = TextEditingController();
  Map<String, dynamic>? _setup;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref.read(authRepositoryProvider).setupTwoFactor();
      if (mounted) setState(() => _setup = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось подготовить 2FA');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Введите 6-значный код');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).enableTwoFactor(code);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Неверный код');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _setup?['qrDataUrl']?.toString();
    final secret = _setup?['secret']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        if (_setup == null && _busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (qr != null) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.memory(
                base64Decode(qr.split(',').last),
                width: 186,
                height: 186,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Отсканируйте код и введите 6 цифр из приложения.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              height: 1.45,
              color: context.palette.textTertiary,
            ),
          ),
          if (secret != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              secret,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                letterSpacing: 1.4,
                color: context.palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 20,
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
              color: context.palette.text,
              fontFeatures: AppTypography.tabular,
            ),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Включить 2FA',
            icon: Icons.shield_rounded,
            loading: _busy,
            onPressed: _busy ? null : _enable,
          ),
        ] else if (!_busy) ...[
          AppButton(
            label: 'Повторить',
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SessionsSheet extends ConsumerWidget {
  const _SessionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sessionsProvider);
    final sessions = async.value ?? const <Map<String, dynamic>>[];

    if (async.isLoading && sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.devices_other_outlined,
        title: 'Пока нет сессий',
        message: 'История входов появится после работы в приложении или вебе.',
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final session in sessions.take(20)) ...[
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            radius: 14,
            child: Row(
              children: [
                SurfaceIcon(
                  icon: Icons.computer_rounded,
                  color: context.palette.ice,
                  size: 34,
                  radius: 11,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BizDate.parse(session['loginAt']) == null
                            ? 'Сессия'
                            : 'Вход ${BizDate.dateShort(BizDate.parse(session['loginAt'])!)} · ${BizDate.time(BizDate.parse(session['loginAt'])!)}',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _durationLabel(session),
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10,
                          color: context.palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session['logoutAt'] == null)
                  const AppChip(
                    label: 'Активна',
                    tone: ChipTone.success,
                    compact: true,
                    dot: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
        ],
      ],
    );
  }

  static String _durationLabel(Map<String, dynamic> session) {
    final raw = session['durationHours'];
    final hours = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    final lastSeen = BizDate.parse(session['lastSeenAt']);
    final suffix = lastSeen == null
        ? ''
        : ' · активность ${BizDate.relative(lastSeen)}';
    return '${Money.hours(hours)}$suffix';
  }
}
