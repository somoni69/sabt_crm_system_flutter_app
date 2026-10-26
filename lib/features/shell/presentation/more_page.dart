import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notifications_providers.dart';
import 'navigation_helpers.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final unread = ref.watch(unreadNotificationsProvider).value?.data ?? 0;
    final canSmm = canSeeSmmSection(user);
    final canProjects = canSeeProjects(user);
    final canClients = canSeeClients(user);
    final canEmployees = canSeeEmployees(user);
    final canCalendar = canUseCalendar(user);
    final checks = canCheckStories(user);
    final firebase = ref.watch(firebaseRuntimeProvider);
    final realtime = ref.watch(realtimeConnectedProvider);

    final workspace = <Widget>[
      if (canSmm)
        _MenuRow(
          icon: Icons.auto_awesome_outlined,
          color: AppColors.accent,
          title: 'SMM и контент-план',
          subtitle: 'Сторис, публикации, проекты',
          onTap: () => openShellTab(ref, 'work'),
        ),
      if (canProjects)
        _MenuRow(
          icon: Icons.workspaces_outline,
          color: AppColors.ice,
          title: 'Проекты',
          subtitle: 'Прогресс, команда и нормы',
          onTap: () => context.push('/projects'),
        ),
      if (canCalendar)
        _MenuRow(
          icon: Icons.calendar_month_outlined,
          color: AppColors.info,
          title: 'Календарь',
          subtitle: 'Встречи, дедлайны и платежи',
          onTap: () => context.push('/calendar'),
        ),
      if (canClients)
        _MenuRow(
          icon: Icons.people_outline_rounded,
          color: AppColors.success,
          title: 'Клиенты',
          subtitle: 'Лиды, статусы и контакты',
          onTap: () => context.push('/clients'),
        ),
      if (canEmployees)
        _MenuRow(
          icon: Icons.badge_outlined,
          color: AppColors.warning,
          title: 'Сотрудники',
          subtitle: 'Команда, контакты и загрузка',
          onTap: () => context.push('/employees'),
        ),
      if (checks)
        _MenuRow(
          icon: Icons.fact_check_outlined,
          color: AppColors.warning,
          title: 'Проверка сторис',
          subtitle: 'Дневная норма по проектам',
          onTap: () => context.push('/stories-check'),
        ),
    ];

    final webItems = <Widget>[
      if (userCan(user, Perm.analyticsView))
        _MenuRow(
          icon: Icons.insights_outlined,
          color: AppColors.accentBright,
          title: 'Аналитика',
          subtitle: 'Полные графики — в вебе',
          trailingLabel: 'WEB',
          onTap: () => context.push('/web-only?path=${Uri.encodeComponent('/analytics')}'),
        ),
      if (canSeeFinance(user))
        _MenuRow(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
          title: 'Финансы',
          subtitle: 'Оплаты и тарифы — в вебе',
          trailingLabel: 'WEB',
          onTap: () => context.push('/web-only?path=${Uri.encodeComponent('/finance')}'),
        ),
      if (canSeeDevSection(user) || userCan(user, Perm.devTrackerView))
        _MenuRow(
          icon: Icons.terminal_rounded,
          color: AppColors.ice,
          title: 'Dev-доска',
          subtitle: 'Канбан разработки — в вебе',
          trailingLabel: 'WEB',
          onTap: () => context.push('/web-only?path=${Uri.encodeComponent('/dev-board')}'),
        ),
      if (userCan(user, Perm.filesView))
        _MenuRow(
          icon: Icons.folder_open_rounded,
          color: AppColors.warning,
          title: 'Файлы',
          subtitle: 'Общее хранилище — в вебе',
          trailingLabel: 'WEB',
          onTap: () => context.push('/web-only?path=${Uri.encodeComponent('/files')}'),
        ),
      if (userCan(user, Perm.tariffsManage))
        _MenuRow(
          icon: Icons.local_offer_outlined,
          color: AppColors.accent,
          title: 'Тарифы',
          subtitle: 'Управление тарифами — в вебе',
          trailingLabel: 'WEB',
          onTap: () => context.push('/web-only?path=${Uri.encodeComponent('/tariffs')}'),
        ),
      if (userCan(user, Perm.archiveView))
        _MenuRow(
          icon: Icons.inventory_2_outlined,
          color: AppColors.textSecondary,
          title: 'Архив',
          subtitle: 'Завершённые проекты и задачи',
          trailingLabel: 'WEB',
          onTap: () => context.push('/web-only?path=${Uri.encodeComponent('/archive')}'),
        ),
    ];

    return AppPage(
      header: AppHeader(
        title: 'Ещё',
        subtitle: user.combinedRoleLabel,
        leading: AppAvatar(
          name: user.name,
          avatar: user.avatar,
          size: 38,
          ring: true,
          onTap: () => context.push('/profile'),
        ),
        actions: [
          AppIconButton(
            icon: Icons.settings_outlined,
            size: 40,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      bottomPadding: PageInsets.bottomNav(context) + 60,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                overline: 'НАВИГАЦИЯ',
                title: 'Все разделы',
                subtitle:
                    'Рабочие инструменты Sabt: то, что удобно делать с телефона, и переходы в веб-версию.',
                trailing: AppChip(
                  label: user.roleLabel,
                  tone: ChipTone.accent,
                  compact: true,
                ),
              ),
              if (workspace.isNotEmpty) ...[
                const SectionHeader(
                  overline: 'РАБОТА',
                  title: 'Рабочее пространство',
                ),
                _MenuGroup(children: workspace),
                const SizedBox(height: 20),
              ],
              const SectionHeader(
                overline: 'АККАУНТ',
                title: 'Профиль и связь',
              ),
              _MenuGroup(
                children: [
                  _MenuRow(
                    icon: Icons.person_outline_rounded,
                    color: AppColors.accentBright,
                    title: 'Профиль',
                    subtitle: '${user.email} · ${user.displayPosition}',
                    onTap: () => context.push('/profile'),
                  ),
                  _MenuRow(
                    icon: Icons.notifications_none_rounded,
                    color: AppColors.info,
                    title: 'Уведомления',
                    subtitle: unread > 0
                        ? '$unread непрочитанных'
                        : 'Всё прочитано',
                    trailingLabel: unread > 0 ? '$unread' : null,
                    onTap: () => context.push('/notifications'),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    color: AppColors.textSecondary,
                    title: 'Настройки',
                    subtitle: 'Кэш, диагностика, безопасность',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
              if (webItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader(
                  overline: 'ВЕБ-ВЕРСИЯ',
                  title: 'Полные инструменты',
                ),
                _MenuGroup(children: webItems),
              ],
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(15),
                radius: 18,
                child: Row(
                  children: [
                    const SurfaceIcon(
                      icon: Icons.verified_user_outlined,
                      color: AppColors.success,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Защищённое соединение',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Realtime ${realtime ? 'подключён' : 'ожидает'} · '
                            'Firebase ${firebase.messagingEnabled ? 'включён' : 'локально'} · '
                            'v${AppEnv.appVersion}',
                            style: const TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 10.5,
                              height: 1.4,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Выйти из аккаунта',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: () => showConfirmSheet(
                  context: context,
                  title: 'Выйти из Sabt?',
                  message:
                      'Локальный кэш этого профиля будет очищен. Данные в компании останутся без изменений.',
                  confirmLabel: 'Выйти',
                  danger: true,
                  onConfirm: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Sabt CRM · WeBrand · Душанбе ${DateTime.now().year}',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    color: AppColors.textDisabled,
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


class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      radius: 20,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.borderSoft),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        children: [
          SurfaceIcon(icon: icon, color: color, size: 36, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (trailingLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
              ),
              child: Text(
                trailingLabel!,
                style: const TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.accentBright,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
    if (onTap == null) return row;
    return PressableScale(onTap: onTap, haptic: false, child: row);
  }
}
