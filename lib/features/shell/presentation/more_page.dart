import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../work_shifts/presentation/work_shift_card.dart';
import 'navigation_helpers.dart';

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _visible(_MenuRow row) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return row.title.toLowerCase().contains(query) ||
        row.subtitle.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final unread = ref.watch(unreadNotificationsProvider).value?.data ?? 0;
    final canSmm = canSeeSmmSection(user);
    final canProjects = canSeeProjects(user);
    final canClients = canSeeClients(user);
    final canEmployees = canSeeEmployees(user);
    final canCalendar = canUseCalendar(user);
    final checks = canCheckStories(user);

    final workspace = <_MenuRow>[
      if (canSmm)
        _MenuRow(
          icon: Icons.auto_awesome_outlined,
          color: context.palette.accent,
          title: 'SMM и контент-план',
          subtitle: 'Сторис, публикации, проекты',
          onTap: () => openShellTab(ref, 'work'),
        ),
      if (canProjects)
        _MenuRow(
          icon: Icons.workspaces_outline,
          color: context.palette.ice,
          title: 'Проекты',
          subtitle: 'Прогресс, команда и нормы',
          onTap: () => context.push('/projects'),
        ),
      if (canCalendar)
        _MenuRow(
          icon: Icons.calendar_month_outlined,
          color: context.palette.info,
          title: 'Календарь',
          subtitle: 'Встречи, дедлайны и платежи',
          onTap: () => context.push('/calendar'),
        ),
      if (canClients)
        _MenuRow(
          icon: Icons.people_outline_rounded,
          color: context.palette.success,
          title: 'Клиенты',
          subtitle: 'Лиды, статусы и контакты',
          onTap: () => context.push('/clients'),
        ),
      if (isSalesManagerRole(user) && canClients)
        _MenuRow(
          icon: Icons.filter_alt_outlined,
          color: context.palette.accentBright,
          title: 'Онбординг',
          subtitle: 'Воронка клиентов и запуск',
          onTap: () => context.push('/onboarding'),
        ),
      if (canEmployees) ...[
        _MenuRow(
          icon: Icons.badge_outlined,
          color: context.palette.warning,
          title: 'Сотрудники',
          subtitle: 'Команда, контакты и загрузка',
          onTap: () => context.push('/employees'),
        ),
        _MenuRow(
          icon: Icons.account_tree_outlined,
          color: context.palette.ice,
          title: 'Оргструктура',
          subtitle: 'Отделы и руководители компании',
          onTap: () => context.push('/employees/org'),
        ),
        if (canManageAccess(user)) ...[
          _MenuRow(
            icon: Icons.speed_rounded,
            color: context.palette.success,
            title: 'KPI сотрудников',
            subtitle: 'Рейтинг и выполнение норм',
            onTap: () => context.push('/employees/kpi'),
          ),
          _MenuRow(
            icon: Icons.calendar_view_week_rounded,
            color: context.palette.info,
            title: 'Задачи недели',
            subtitle: 'Распределение нагрузки по дням',
            onTap: () => context.push('/employees/week'),
          ),
          _MenuRow(
            icon: Icons.history_toggle_off_rounded,
            color: context.palette.accentBright,
            title: 'Активность и смены',
            subtitle: 'Табель месяца, смены и лента команды',
            onTap: () => context.push('/employees/activity'),
          ),
        ],
      ],
      if (user.isFounder)
        _MenuRow(
          icon: Icons.flag_outlined,
          color: context.palette.success,
          title: 'План продаж',
          subtitle: 'Суммы менеджеров на месяц',
          onTap: () => context.push('/employees/sales-plan'),
        ),
      if (canManageAccess(user))
        _MenuRow(
          icon: Icons.admin_panel_settings_outlined,
          color: context.palette.ice,
          title: 'Доступы сотрудников',
          subtitle: 'Матрица прав и персональные гранты',
          onTap: () => context.push('/employee-access'),
        ),
      if (checks)
        _MenuRow(
          icon: Icons.fact_check_outlined,
          color: context.palette.warning,
          title: 'Проверка сторис',
          subtitle: 'Дневная норма по проектам',
          onTap: () => context.push('/stories-check'),
        ),
      if (canSmm)
        _MenuRow(
          icon: Icons.checklist_rounded,
          color: context.palette.success,
          title: 'SMM-Контроль',
          subtitle: 'Здоровье проектов и публикации',
          onTap: () => context.push('/smm/control'),
        ),
      if (userCan(user, Perm.notesUse))
        _MenuRow(
          icon: Icons.sticky_note_2_outlined,
          color: context.palette.accent,
          title: 'Мои заметки',
          subtitle: 'Личные задачи и напоминания',
          onTap: () => context.push('/my-notes'),
        ),
    ];

    final systemTools = <_MenuRow>[
      if (userCan(user, Perm.aiChat))
        _MenuRow(
          icon: Icons.auto_awesome,
          color: context.palette.accentBright,
          title: 'ИИ-помощник',
          subtitle: 'Умная аналитика и поиск по CRM',
          onTap: () => context.push('/ai'),
        ),
      if (userCan(user, Perm.analyticsView))
        _MenuRow(
          icon: Icons.insights_outlined,
          color: context.palette.accentBright,
          title: 'Аналитика',
          subtitle: 'Сводные показатели и графики',
          onTap: () => context.push('/analytics'),
        ),
      if (userCan(user, Perm.risksView) || user.isFounder || user.isAdmin)
        _MenuRow(
          icon: Icons.warning_amber_rounded,
          color: context.palette.danger,
          title: 'Риски',
          subtitle: 'План-факт, отставания и перегрузка',
          onTap: () => context.push('/risks'),
        ),
      if (canSeeFinance(user))
        _MenuRow(
          icon: Icons.account_balance_wallet_outlined,
          color: context.palette.success,
          title: 'Финансы',
          subtitle: 'Оплаты, счета и прибыль',
          onTap: () => context.push('/finance'),
        ),
      _MenuRow(
        icon: Icons.directions_car_outlined,
        color: context.palette.ice,
        title: 'Транспорт',
        subtitle: 'Компенсации за рабочие поездки',
        onTap: () => context.push('/transport'),
      ),
      if (canSeeDevSection(user) || userCan(user, Perm.devTrackerView)) ...[
        _MenuRow(
          icon: Icons.view_kanban_outlined,
          color: context.palette.ice,
          title: 'Доска',
          subtitle: 'Канбан разработки',
          onTap: () => context.push('/dev-board'),
        ),
        _MenuRow(
          icon: Icons.folder_outlined,
          color: context.palette.accentBright,
          title: 'Проекты разработки',
          subtitle: 'Этапы, сроки сдачи и команда',
          onTap: () => context.push('/dev/projects'),
        ),
        _MenuRow(
          icon: Icons.speed_rounded,
          color: context.palette.success,
          title: 'KPI',
          subtitle: 'Загрузка команды разработки',
          onTap: () => context.push('/dev-board/kpi'),
        ),
        if (isDevLead(user) || userCan(user, Perm.devTrackerManage))
          _MenuRow(
            icon: Icons.summarize_outlined,
            color: context.palette.warning,
            title: 'Отчёты',
            subtitle: 'Сводка по доске разработки',
            onTap: () => context.push('/dev-board/reports'),
          ),
      ],
      if (userCan(user, Perm.filesView))
        _MenuRow(
          icon: Icons.folder_open_rounded,
          color: context.palette.warning,
          title: 'Файлы',
          subtitle: 'Хранилище документов и медиа',
          onTap: () => context.push('/files'),
        ),
      if (userCan(user, Perm.tariffsManage))
        _MenuRow(
          icon: Icons.local_offer_outlined,
          color: context.palette.accent,
          title: 'Тарифы',
          subtitle: 'Управление пакетами услуг',
          onTap: () => context.push('/tariffs'),
        ),
      if (userCan(user, Perm.archiveView))
        _MenuRow(
          icon: Icons.inventory_2_outlined,
          color: context.palette.textSecondary,
          title: 'Архив',
          subtitle: 'Завершённые проекты',
          onTap: () => context.push('/archive'),
        ),
      if (userCan(user, Perm.securityLogView) || user.isAdmin || user.isFounder)
        _MenuRow(
          icon: Icons.shield_outlined,
          color: context.palette.textSecondary,
          title: 'Журнал безопасности',
          subtitle: 'Аудит действий и авторизаций',
          onTap: () => context.push('/security-log'),
        ),
    ];

    final work = workspace.where(_visible).toList();
    final tools = systemTools.where(_visible).toList();
    final account = <_MenuRow>[
      _MenuRow(
        icon: Icons.person_outline_rounded,
        color: context.palette.accentBright,
        title: 'Профиль',
        subtitle: '${user.email} · ${user.displayPosition}',
        onTap: () => context.push('/profile'),
      ),
      _MenuRow(
        icon: Icons.notifications_none_rounded,
        color: context.palette.info,
        title: 'Уведомления',
        subtitle: unread > 0 ? '$unread непрочитанных' : 'Всё прочитано',
        trailingLabel: unread > 0 ? '$unread' : null,
        onTap: () => context.push('/notifications'),
      ),
      _MenuRow(
        icon: Icons.settings_outlined,
        color: context.palette.textSecondary,
        title: 'Настройки',
        subtitle: 'Тема, кэш и безопасность',
        onTap: () => context.push('/settings'),
      ),
    ].where(_visible).toList();
    final nothing = _query.trim().isNotEmpty &&
        work.isEmpty &&
        tools.isEmpty &&
        account.isEmpty;

    return AppPage(
      header: const AppHeader(title: 'Ещё'),
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!user.isFounder && _query.trim().isEmpty) ...[
                const WorkShiftBannerCard(),
                const SizedBox(height: 12),
              ],
              AppSearchField(
                controller: _search,
                hint: 'Найти раздел',
                onChanged: (value) => setState(() => _query = value),
                onClear: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: 14),
              if (nothing)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Ничего не нашлось',
                  message: 'Попробуйте короче — например, «доска» или «клиент».',
                  compact: true,
                ),
              if (work.isNotEmpty) ...[
                const SectionHeader(title: 'Разделы'),
                _MenuGroup(children: work),
                const SizedBox(height: 16),
              ],
              if (account.isNotEmpty) ...[
                const SectionHeader(title: 'Аккаунт'),
                _MenuGroup(children: account),
                const SizedBox(height: 16),
              ],
              if (tools.isNotEmpty) ...[
                const SectionHeader(title: 'Сервисы'),
                _MenuGroup(children: tools),
                const SizedBox(height: 16),
              ],
              AppButton(
                label: 'Выйти из аккаунта',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: () => showConfirmSheet(
                  context: context,
                  title: 'Выйти из WeBrand?',
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
                  'WeBrand CRM · Душанбе ${DateTime.now().year}',
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    color: context.palette.textDisabled,
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
               Divider(height: 1, thickness: 1, color: context.palette.borderSoft),
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
          Icon(
            icon,
            size: 20,
            color: Color.alphaBlend(
              color.withValues(alpha: 0.22),
              context.palette.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (trailingLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: context.palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: context.palette.accent.withValues(alpha: 0.22)),
              ),
              child: Text(
                trailingLabel!,
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: context.palette.accentBright,
                ),
              ),
            ),
          const SizedBox(width: 4),
           Icon(Icons.chevron_right_rounded, size: 18, color: context.palette.textTertiary),
        ],
      ),
    );
    if (onTap == null) return row;
    return PressableScale(onTap: onTap, haptic: false, child: row);
  }
}
