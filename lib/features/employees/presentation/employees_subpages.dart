import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../work_shifts/presentation/work_shift_card.dart';
import '../domain/employee.dart';
import 'employees_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. ОРГСТРУКТУРА (/employees/org)
// ═══════════════════════════════════════════════════════════════════════════

class EmployeesOrgPage extends ConsumerWidget {
  const EmployeesOrgPage({super.key});

  static const _departments = [
    (
      key: 'smm',
      title: 'SMM',
      head: 'smm_director',
      members: ['smm_specialist', 'targetologist', 'designer'],
    ),
    (
      key: 'video',
      title: 'Видеография',
      head: null,
      members: ['videographer', 'video_editor'],
    ),
    (
      key: 'dev',
      title: 'Разработка',
      head: 'dev_director',
      members: ['pm_dev', 'developer'],
    ),
    (
      key: 'sales',
      title: 'Продажи',
      head: null,
      members: ['sales_manager_smm', 'sales_manager_dev'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(employeesProvider);
    final all = async.value?.data ?? const <EmployeeModel>[];
    final smmLead = user?.role == 'smm_director';
    final active = all.where((e) {
      if (!e.isActive) return false;
      if (!smmLead) return true;
      return e.role == 'smm_specialist' ||
          e.role == 'smm_director' ||
          e.position == 'SMM специалист' ||
          e.position == 'Руководитель SMM';
    }).toList();

    final assigned = <String>{};
    List<EmployeeModel> take(bool Function(EmployeeModel) pred) {
      final res =
          active.where((e) => !assigned.contains(e.id) && pred(e)).toList();
      for (final e in res) {
        assigned.add(e.id);
      }
      return res;
    }

    bool isRole(EmployeeModel e, String role) =>
        e.role == role || e.position == (UserModel.roleLabels[role] ?? '');

    final owners = take(
      (e) =>
          e.role == 'founder' ||
          e.position == 'Основатель' ||
          e.position == 'Сооснователь',
    );
    final admins =
        take((e) => e.role == 'admin' || e.position == 'Администратор');
    final depts = _departments
        .map(
          (d) => (
            key: d.key,
            title: d.title,
            hasHeadRole: d.head != null,
            heads: d.head != null
                ? take((e) => isRole(e, d.head!))
                : <EmployeeModel>[],
            members:
                take((e) => d.members.any((role) => isRole(e, role))),
          ),
        )
        .where((d) => d.heads.isNotEmpty || d.members.isNotEmpty)
        .toList();
    final others = active.where((e) => !assigned.contains(e.id)).toList();

    return AppPage(
      header: AppHeader(
        title: 'Оргструктура',
        subtitle: 'Иерархия и отделы агентства',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: async.isLoading && all.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.palette.accent,
                    ),
                  ),
                )
              : active.isEmpty
                  ? const EmptyState(
                      icon: Icons.account_tree_outlined,
                      title: 'Сотрудников пока нет',
                      message: 'Активные сотрудники появятся в оргструктуре.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (owners.isNotEmpty) ...[
                          const SectionHeader(
                            overline: 'УРОВЕНЬ 1',
                            title: 'Руководство компании',
                          ),
                          for (final emp in owners) ...[
                            _OrgPersonTile(
                              employee: emp,
                              highlight: true,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                        if (admins.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const SectionHeader(
                            overline: 'УРОВЕНЬ 2',
                            title: 'Администрация',
                          ),
                          for (final emp in admins) ...[
                            _OrgPersonTile(
                              employee: emp,
                              highlight: true,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                        for (final dept in depts) ...[
                          const SizedBox(height: 12),
                          SectionHeader(
                            overline: 'ОТДЕЛ',
                            title: dept.title,
                          ),
                          AppCard(
                            padding: const EdgeInsets.all(12),
                            radius: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (dept.heads.isNotEmpty)
                                  for (final head in dept.heads)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _OrgPersonTile(
                                        employee: head,
                                        highlight: true,
                                        badge: 'Руководитель',
                                      ),
                                    )
                                else if (dept.hasHeadRole)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: context.palette.borderSoft,
                                        ),
                                      ),
                                      child: Text(
                                        'Руководитель не назначен',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.palette.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                                for (final member in dept.members)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _OrgPersonTile(employee: member),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (others.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const SectionHeader(
                            overline: 'КОМАНДА',
                            title: 'Другие сотрудники',
                          ),
                          for (final emp in others) ...[
                            _OrgPersonTile(employee: emp),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

class _OrgPersonTile extends StatelessWidget {
  const _OrgPersonTile({
    required this.employee,
    this.highlight = false,
    this.badge,
  });

  final EmployeeModel employee;
  final bool highlight;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 16,
      borderColor: highlight
          ? palette.accent.withValues(alpha: 0.35)
          : palette.borderSoft,
      onTap: () => context.push('/employees/${employee.id}'),
      child: Row(
        children: [
          AppAvatar(
            name: employee.fullName,
            avatar: employee.avatar,
            size: highlight ? 40 : 36,
            ring: highlight,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.position.isNotEmpty
                      ? employee.position
                      : (UserModel.roleLabels[employee.role] ?? employee.role),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            AppChip(
              label: badge!,
              tone: ChipTone.accent,
              compact: true,
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textTertiary,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. KPI СОТРУДНИКОВ (/employees/kpi)
// ═══════════════════════════════════════════════════════════════════════════

enum KpiPeriod { today, week, month, prevMonth }

extension KpiPeriodExt on KpiPeriod {
  String get label => switch (this) {
        KpiPeriod.today => 'Сегодня',
        KpiPeriod.week => 'Неделя',
        KpiPeriod.month => 'Месяц',
        KpiPeriod.prevMonth => 'Прошлый месяц',
      };

  ({String from, String to}) range() {
    final now = DateTime.now();
    final todayIso = BizDate.key(now);
    return switch (this) {
      KpiPeriod.today => (from: todayIso, to: todayIso),
      KpiPeriod.week => (
          from: BizDate.key(now.subtract(Duration(days: now.weekday - 1))),
          to: todayIso,
        ),
      KpiPeriod.month => (
          from: BizDate.key(DateTime(now.year, now.month, 1)),
          to: todayIso,
        ),
      KpiPeriod.prevMonth => (
          from: BizDate.key(DateTime(now.year, now.month - 1, 1)),
          to: BizDate.key(DateTime(now.year, now.month, 0)),
        ),
    };
  }
}

final employeesKpiProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, KpiPeriod>((ref, period) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final range = period.range();
  final raw = await api.getJson(
    '/kpi/all',
    query: {'from': range.from, 'to': range.to},
  );
  return asList(raw).map(asMap).whereType<Map<String, dynamic>>().toList();
});

class EmployeesKpiPage extends ConsumerStatefulWidget {
  const EmployeesKpiPage({super.key});

  @override
  ConsumerState<EmployeesKpiPage> createState() => _EmployeesKpiPageState();
}

class _EmployeesKpiPageState extends ConsumerState<EmployeesKpiPage> {
  KpiPeriod _period = KpiPeriod.month;

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(employeesKpiProvider(_period));
    final empAsync = ref.watch(employeesProvider);
    final employees = empAsync.value?.data ?? const <EmployeeModel>[];
    final palette = context.palette;

    final byUser = <String, EmployeeModel>{
      for (final e in employees)
        if ((e.userId ?? '').isNotEmpty) e.userId!: e,
    };

    return AppPage(
      header: AppHeader(
        title: 'KPI сотрудников',
        subtitle: 'Рейтинг и выполнение норм',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(employeesKpiProvider(_period).future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in KpiPeriod.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppFilterChip(
                          label: p.label,
                          active: _period == p,
                          onTap: () => setState(() => _period = p),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              kpiAsync.when(
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                ),
                error: (err, _) => InlineError(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(employeesKpiProvider(_period)),
                ),
                data: (rawList) {
                  final rows = rawList.map((k) {
                    final uid = asStringOr(k['userId'], '');
                    final emp = byUser[uid];
                    final noData = asBool(k['noData']);
                    final pct = noData ? null : asIntOr(k['overallPercent'], 0);
                    return (
                      userId: uid,
                      empId: emp?.id,
                      name: emp?.fullName ?? asStringOr(k['name'], 'Сотрудник'),
                      position: emp?.position ?? '',
                      avatar: emp?.avatar,
                      percent: pct,
                    );
                  }).toList()
                    ..sort((a, b) {
                      final aNull = a.percent == null ? 1 : 0;
                      final bNull = b.percent == null ? 1 : 0;
                      if (aNull != bNull) return aNull.compareTo(bNull);
                      final cmp = (b.percent ?? 0).compareTo(a.percent ?? 0);
                      if (cmp != 0) return cmp;
                      return a.name.compareTo(b.name);
                    });

                  if (rows.isEmpty) {
                    return const EmptyState(
                      icon: Icons.speed_rounded,
                      title: 'KPI пока не считается',
                      message: 'За выбранный период нет оценок KPI.',
                    );
                  }

                  final rated =
                      rows.where((r) => r.percent != null).toList();
                  final avg = rated.isEmpty
                      ? null
                      : (rated.fold<int>(0, (s, r) => s + r.percent!) /
                              rated.length)
                          .round();
                  final full = rated.where((r) => r.percent! >= 100).length;
                  final low = rated.where((r) => r.percent! < 50).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _KpiSummaryTile(
                              value: avg == null ? '—' : '$avg %',
                              label: 'Средний KPI',
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _KpiSummaryTile(
                              value: '$full',
                              label: 'План 100 %',
                              color: palette.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _KpiSummaryTile(
                              value: '$low',
                              label: 'Ниже 50 %',
                              color: palette.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < rows.length; i++) ...[
                        _KpiRowCard(
                          rank: rows[i].percent == null ? null : i + 1,
                          name: rows[i].name,
                          position: rows[i].position,
                          avatar: rows[i].avatar,
                          percent: rows[i].percent,
                          onTap: rows[i].empId == null
                              ? null
                              : () =>
                                  context.push('/employees/${rows[i].empId}'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiSummaryTile extends StatelessWidget {
  const _KpiSummaryTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 11,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRowCard extends StatelessWidget {
  const _KpiRowCard({
    required this.rank,
    required this.name,
    required this.position,
    required this.avatar,
    required this.percent,
    this.onTap,
  });

  final int? rank;
  final String name;
  final String position;
  final String? avatar;
  final int? percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pct = percent;
    final color = pct == null
        ? palette.textTertiary
        : pct >= 80
            ? palette.success
            : pct >= 50
                ? palette.warning
                : palette.danger;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      radius: 16,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  rank == null ? '—' : '$rank',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: rank == 1 ? palette.warning : palette.textTertiary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ),
              AppAvatar(name: name, avatar: avatar, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    if (position.isNotEmpty)
                      Text(
                        position,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                pct == null ? '—' : '$pct %',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: palette.surface3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. ЗАДАЧИ НЕДЕЛИ (/employees/week)
// ═══════════════════════════════════════════════════════════════════════════

class EmployeesWeekPage extends ConsumerStatefulWidget {
  const EmployeesWeekPage({super.key});

  @override
  ConsumerState<EmployeesWeekPage> createState() => _EmployeesWeekPageState();
}

class _EmployeesWeekPageState extends ConsumerState<EmployeesWeekPage> {
  int _weekOffset = 0;
  String _filter = 'all'; // 'all' | 'late' | 'free'
  bool _repeating = false;

  DateTime _mondayOfWeek(int offset) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: offset * 7));
  }

  Future<void> _repeatPreviousWeek(String weekStart) async {
    if (_repeating) return;
    setState(() => _repeating = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson('/tasks/repeat-week', body: {'weekStart': weekStart});
      ref.read(dataRevisionProvider.notifier).bump();
      ref.read(dependenciesProvider).banners.show(
            const AppBanner(
              title: 'Неделя скопирована',
              message: 'Задачи прошлой недели перенесены на выбранную неделю.',
              tone: BannerTone.success,
            ),
          );
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Не удалось повторить неделю',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _mondayOfWeek(_weekOffset);
    final end = start.add(const Duration(days: 6));
    final fromIso = BizDate.key(start);
    final toIso = BizDate.key(end);
    final todayIso = BizDate.todayKey();
    final palette = context.palette;

    final empAsync = ref.watch(employeesProvider);
    final employees = (empAsync.value?.data ?? const <EmployeeModel>[])
        .where((e) => e.isActive && (e.userId ?? '').isNotEmpty)
        .toList();

    final weekTasksFuture = ref.watch(_weekTasksProvider((from: fromIso, to: toIso)));

    return AppPage(
      header: AppHeader(
        title: 'Задачи недели',
        subtitle: '${BizDate.dateShort(start)} — ${BizDate.dateShort(end)}',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.copy_all_rounded,
            size: 40,
            tooltip: 'Повторить прошлую неделю',
            onPressed: _repeating ? null : () => _repeatPreviousWeek(fromIso),
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                radius: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppIconButton(
                      icon: Icons.chevron_left_rounded,
                      size: 34,
                      onPressed: () => setState(() => _weekOffset--),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _weekOffset = 0),
                      child: Text(
                        _weekOffset == 0
                            ? 'ТЕКУЩАЯ НЕДЕЛЯ · ${BizDate.dateShort(start)} — ${BizDate.dateShort(end)}'
                            : '${BizDate.dateShort(start)} — ${BizDate.dateShort(end)}',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.chevron_right_rounded,
                      size: 34,
                      onPressed: () => setState(() => _weekOffset++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Все сотрудники',
                      active: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    AppFilterChip(
                      label: 'С просрочкой',
                      active: _filter == 'late',
                      onTap: () => setState(() => _filter = 'late'),
                    ),
                    const SizedBox(width: 8),
                    AppFilterChip(
                      label: 'Свободны',
                      active: _filter == 'free',
                      onTap: () => setState(() => _filter = 'free'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              weekTasksFuture.when(
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                ),
                error: (err, _) => InlineError(
                  message: err.toString(),
                  onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (items) {
                  final byOwner = <String, List<Map<String, dynamic>>>{};
                  for (final it in items) {
                    final uid = asStringOr(it['ownerId'], '');
                    if (uid.isEmpty) continue;
                    byOwner.putIfAbsent(uid, () => []).add(it);
                  }

                  final filteredEmployees = employees.where((emp) {
                    final list =
                        byOwner[emp.userId ?? ''] ?? const <Map<String, dynamic>>[];
                    final openCount =
                        list.where((x) => x['done'] != true).length;
                    final lateCount = list
                        .where(
                          (x) =>
                              x['done'] != true &&
                              asStringOr(x['date'], '')
                                      .compareTo(todayIso) <
                                  0,
                        )
                        .length;
                    if (_filter == 'late') return lateCount > 0;
                    if (_filter == 'free') return openCount == 0;
                    return true;
                  }).toList();

                  if (filteredEmployees.isEmpty) {
                    return const EmptyState(
                      icon: Icons.calendar_view_week_rounded,
                      title: 'Нет сотрудников по фильтру',
                      message: 'Попробуйте выбрать другой фильтр или неделю.',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final emp in filteredEmployees) ...[
                        _EmployeeWeekCard(
                          employee: emp,
                          todayIso: todayIso,
                          items: byOwner[emp.userId ?? ''] ?? const [],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final _weekTasksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String from, String to})>(
        (ref, range) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final out = <Map<String, dynamic>>[];

  final rawTasks = await api.getJson(
    '/tasks',
    query: {'deadlineFrom': range.from, 'deadlineBefore': range.to},
  );
  for (final raw in asList(rawTasks)) {
    final m = asMap(raw);
    if (m == null || m['status'] == 'cancelled') continue;
    final date = asStringOr(m['deadline'], '').split('T').first;
    if (date.isEmpty) continue;
    out.add({
      'id': asStringOr(m['id'], ''),
      'title': asStringOr(m['title'], 'Задача'),
      'date': date,
      'done': m['status'] == 'done',
      'ownerId': asString(m['assigneeId']),
      'project': asString(asMap(m['project'])?['name']),
      'kind': 'task',
    });
  }

  try {
    final cal = asMap(
      await api.getJson(
        '/content-plan/smm-calendar',
        query: {'from': range.from, 'to': range.to},
      ),
    );
    for (final raw in asList(cal?['events'])) {
      final e = asMap(raw);
      if (e == null) continue;
      final date = asStringOr(e['date'], '').split('T').first;
      if (date.isEmpty) continue;
      final status = asStringOr(e['status'], '');
      out.add({
        'id': asStringOr(e['itemId'], ''),
        'title': asStringOr(e['title'] ?? e['topic'], 'Контент'),
        'date': date,
        'done': status == 'done' || status == 'published',
        'ownerId': asString(e['assigneeId']),
        'project': asString(e['projectName']),
        'kind': 'plan',
      });
    }
  } catch (_) {
    // SMM calendar is optional for non-SMM roles
  }

  return out;
});

class _EmployeeWeekCard extends StatelessWidget {
  const _EmployeeWeekCard({
    required this.employee,
    required this.todayIso,
    required this.items,
  });

  final EmployeeModel employee;
  final String todayIso;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final doneCount = items.where((x) => x['done'] == true).length;
    final openItems = items.where((x) => x['done'] != true).toList();
    final lateCount = openItems
        .where((x) => asStringOr(x['date'], '').compareTo(todayIso) < 0)
        .length;

    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: employee.fullName,
                avatar: employee.avatar,
                size: 38,
                onTap: () => context.push('/employees/${employee.id}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      employee.position,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (lateCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppChip(
                    label: 'Просрочено $lateCount',
                    tone: ChipTone.danger,
                    compact: true,
                  ),
                ),
              AppChip(
                label: openItems.isEmpty
                    ? (doneCount > 0 ? '✓ $doneCount готово' : 'Свободен')
                    : '${openItems.length} в работе',
                tone: openItems.isEmpty ? ChipTone.success : ChipTone.accent,
                compact: true,
              ),
            ],
          ),
          if (openItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in openItems.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: item['kind'] == 'task' &&
                          asStringOr(item['id'], '').isNotEmpty
                      ? () => context.push('/tasks/${item['id']}')
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: asStringOr(item['date'], '')
                                      .compareTo(todayIso) <
                                  0
                              ? palette.danger
                              : item['kind'] == 'plan'
                                  ? palette.info
                                  : palette.accentBright,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item['title']}'
                          '${item['project'] != null ? ' · ${item['project']}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        asStringOr(item['date'], '').length >= 10
                            ? '${asStringOr(item['date'], '').substring(8, 10)}.${asStringOr(item['date'], '').substring(5, 7)}'
                            : '',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textTertiary,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. АКТИВНОСТЬ И СМЕНЫ КОМАНДЫ (/employees/activity & /team-activity)
// ═══════════════════════════════════════════════════════════════════════════

class EmployeesActivityPage extends ConsumerStatefulWidget {
  const EmployeesActivityPage({super.key});

  @override
  ConsumerState<EmployeesActivityPage> createState() =>
      _EmployeesActivityPageState();
}

class _EmployeesActivityPageState extends ConsumerState<EmployeesActivityPage> {
  String _tab = 'timesheet'; // 'timesheet' | 'today' | 'schedule' | 'feed'

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: AppHeader(
        title: 'Активность и смены',
        subtitle: 'Табель, смены сегодня, график и журнал',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            onPressed: () => ref.read(dataRevisionProvider.notifier).bump(),
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Табель месяца',
                      active: _tab == 'timesheet',
                      onTap: () => setState(() => _tab = 'timesheet'),
                    ),
                    const SizedBox(width: 8),
                    AppFilterChip(
                      label: 'Смены сегодня',
                      active: _tab == 'today',
                      onTap: () => setState(() => _tab = 'today'),
                    ),
                    const SizedBox(width: 8),
                    AppFilterChip(
                      label: 'График работы',
                      active: _tab == 'schedule',
                      onTap: () => setState(() => _tab = 'schedule'),
                    ),
                    const SizedBox(width: 8),
                    AppFilterChip(
                      label: 'Лента событий',
                      active: _tab == 'feed',
                      onTap: () => setState(() => _tab = 'feed'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_tab == 'timesheet') const _TimesheetSection(),
              if (_tab == 'today') const _TodayShiftsSection(),
              if (_tab == 'schedule') const _SchedulesSection(),
              if (_tab == 'feed') const _TeamFeedSection(),
            ],
          ),
        ),
      ],
    );
  }
}

final _timesheetProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw =
      await ref.watch(dependenciesProvider).api.getJson('/work-shifts/month');
  return asMap(raw) ?? const <String, dynamic>{};
});

class _TimesheetSection extends ConsumerWidget {
  const _TimesheetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_timesheetProvider);
    final palette = context.palette;

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      ),
      error: (err, _) => InlineError(
        message: err.toString(),
        onRetry: () => ref.invalidate(_timesheetProvider),
      ),
      data: (data) {
        final items = asList(data['items'] ?? data['rows'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'Табель пуст',
            message: 'За текущий месяц записей о сменах пока нет.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in items) ...[
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                radius: 16,
                child: Row(
                  children: [
                    AppAvatar(
                      name: asStringOr(row['name'], 'Сотрудник'),
                      avatar: asString(row['avatar']),
                      size: 38,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asStringOr(row['name'], 'Сотрудник'),
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            'Смен: ${asIntOr(row['daysWorked'] ?? row['shiftsCount'], 0)}'
                            '${asIntOr(row['lateCount'], 0) > 0 ? ' · опозданий: ${asIntOr(row['lateCount'], 0)}' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatShiftMinutes(
                        asIntOr(row['totalMinutes'] ?? row['minutes'], 0),
                      ),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: palette.accentBright,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

final _todayTeamShiftsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final team = asMap(await api.getJson('/work-shifts/team')) ?? {};
  List<Map<String, dynamic>> notices = const [];
  List<Map<String, dynamic>> edits = const [];
  try {
    notices = asList(await api.getJson('/work-shifts/notices'))
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (_) {}
  try {
    edits = asList(await api.getJson('/work-shifts/edits'))
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (_) {}
  return {'team': team, 'notices': notices, 'edits': edits};
});

class _TodayShiftsSection extends ConsumerWidget {
  const _TodayShiftsSection();

  Future<void> _decide(
    WidgetRef ref,
    String kind,
    String id,
    bool approve,
  ) async {
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .patchJson('/work-shifts/$kind/$id', body: {'approve': approve});
      ref.invalidate(_todayTeamShiftsProvider);
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_todayTeamShiftsProvider);
    final palette = context.palette;

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      ),
      error: (err, _) => InlineError(
        message: err.toString(),
        onRetry: () => ref.invalidate(_todayTeamShiftsProvider),
      ),
      data: (bundle) {
        final team = asMap(bundle['team']) ?? const <String, dynamic>{};
        final rows = asList(team['items'] ?? team['rows'] ?? team['employees'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .toList();
        final notices = (bundle['notices'] as List<Map<String, dynamic>>? ?? [])
            .where((n) => n['status'] == 'pending')
            .toList();
        final edits = (bundle['edits'] as List<Map<String, dynamic>>? ?? [])
            .where((e) => e['status'] == 'pending')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notices.isNotEmpty) ...[
              const SectionHeader(
                overline: 'ЗАПРОСЫ',
                title: 'Предупреждения «Приду позже»',
              ),
              for (final n in notices) ...[
                AppCard(
                  padding: const EdgeInsets.all(13),
                  radius: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asStringOr(
                                n['userName'] ?? asMap(n['user'])?['name'],
                                'Сотрудник',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                            Text(
                              '${n['date'] ?? ''} к ${n['plannedTime'] ?? ''}'
                              '${n['reason'] != null ? ' · ${n['reason']}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Ок',
                        compact: true,
                        expanded: false,
                        onPressed: () =>
                            _decide(ref, 'notices', asStringOr(n['id'], ''), true),
                      ),
                      const SizedBox(width: 6),
                      AppButton(
                        label: 'Отказ',
                        variant: ButtonVariant.danger,
                        compact: true,
                        expanded: false,
                        onPressed: () => _decide(
                          ref,
                          'notices',
                          asStringOr(n['id'], ''),
                          false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (edits.isNotEmpty) ...[
              const SectionHeader(
                overline: 'ПРАВКИ ВРЕМЕНИ',
                title: 'Запросы «Забыл отметить»',
              ),
              for (final e in edits) ...[
                AppCard(
                  padding: const EdgeInsets.all(13),
                  radius: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asStringOr(
                                e['userName'] ?? asMap(e['user'])?['name'],
                                'Сотрудник',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                            Text(
                              '${e['field'] == 'start' ? 'Начало' : 'Конец'}: ${e['time'] ?? ''}'
                              '${e['note'] != null ? ' · ${e['note']}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Ок',
                        compact: true,
                        expanded: false,
                        onPressed: () =>
                            _decide(ref, 'edits', asStringOr(e['id'], ''), true),
                      ),
                      const SizedBox(width: 6),
                      AppButton(
                        label: 'Отказ',
                        variant: ButtonVariant.danger,
                        compact: true,
                        expanded: false,
                        onPressed: () =>
                            _decide(ref, 'edits', asStringOr(e['id'], ''), false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SectionHeader(
              overline: 'СЕГОДНЯ',
              title: 'Смены сотрудников',
            ),
            if (rows.isEmpty)
              const EmptyState(
                icon: Icons.access_time_rounded,
                title: 'Смен за сегодня пока нет',
                message: 'Когда сотрудники начнут день, они появятся здесь.',
                compact: true,
              )
            else
              for (final r in rows) ...[
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  radius: 16,
                  child: Row(
                    children: [
                      AppAvatar(
                        name: asStringOr(r['name'], 'Сотрудник'),
                        avatar: asString(r['avatar']),
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asStringOr(r['name'], 'Сотрудник'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: palette.text,
                              ),
                            ),
                            Text(
                              r['state'] == 'working'
                                  ? 'На смене с ${r['startedLabel'] ?? '—'}'
                                  : r['state'] == 'paused'
                                      ? 'Перерыв'
                                      : 'Не на смене',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppChip(
                        label: formatShiftMinutes(
                          asIntOr(r['todayMinutes'] ?? r['minutes'], 0),
                        ),
                        tone: r['state'] == 'working'
                            ? ChipTone.success
                            : r['state'] == 'paused'
                                ? ChipTone.warning
                                : ChipTone.neutral,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

final _schedulesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw = await ref
      .watch(dependenciesProvider)
      .api
      .getJson('/work-shifts/schedules');
  return asMap(raw) ?? const <String, dynamic>{};
});

class _SchedulesSection extends ConsumerWidget {
  const _SchedulesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_schedulesProvider);
    final palette = context.palette;

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      ),
      error: (err, _) => InlineError(
        message: err.toString(),
        onRetry: () => ref.invalidate(_schedulesProvider),
      ),
      data: (data) {
        final company = asMap(data['company']);
        final users = asList(data['users'] ?? data['items'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (company != null) ...[
              AppCard(
                padding: const EdgeInsets.all(14),
                radius: 16,
                child: Row(
                  children: [
                    SurfaceIcon(
                      icon: Icons.business_rounded,
                      color: palette.accentBright,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'График компании по умолчанию',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            '${company['start'] ?? '09:00'} — ${company['end'] ?? '18:00'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (users.isEmpty)
              const EmptyState(
                icon: Icons.event_repeat_rounded,
                title: 'Графики не загружены',
                message: 'Индивидуальные графики сотрудников появятся здесь.',
                compact: true,
              )
            else
              for (final u in users) ...[
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  radius: 16,
                  child: Row(
                    children: [
                      AppAvatar(
                        name: asStringOr(u['name'], 'Сотрудник'),
                        avatar: asString(u['avatar']),
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          asStringOr(u['name'], 'Сотрудник'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: palette.text,
                          ),
                        ),
                      ),
                      Text(
                        '${u['start'] ?? '09:00'} — ${u['end'] ?? '18:00'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: palette.textSecondary,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

final _teamFeedProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw = await ref
      .watch(dependenciesProvider)
      .api
      .getJson('/activity-log/team', query: {'limit': 50});
  final map = asMap(raw);
  final list = map != null ? asList(map['items']) : asList(raw);
  return list.map(asMap).whereType<Map<String, dynamic>>().toList();
});

class _TeamFeedSection extends ConsumerWidget {
  const _TeamFeedSection();

  static const _actionLabels = <String, String>{
    'LOGIN': 'Вошёл в систему',
    'LOGOUT': 'Вышел из системы',
    'TASK_CREATE': 'Создал задачу',
    'TASK_UPDATE': 'Изменил задачу',
    'TASK_DELETE': 'Удалил задачу',
    'TASK_STATUS': 'Сменил статус задачи',
    'PROJECT_CREATE': 'Создал проект',
    'PROJECT_UPDATE': 'Изменил проект',
    'COMMENT_CREATE': 'Оставил комментарий',
    'STORY_UPDATE': 'Обновил сторис',
    'TASK_RESULT_SUBMIT': 'Сдал задачу на проверку',
    'TASK_REVIEW_APPROVE': 'Принял задачу',
    'TASK_REVIEW_RETURN': 'Вернул задачу на доработку',
    'LEAD_PROGRESS': 'Продвинул лида по воронке',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_teamFeedProvider);
    final palette = context.palette;

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      ),
      error: (err, _) => InlineError(
        message: err.toString(),
        onRetry: () => ref.invalidate(_teamFeedProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'Событий пока нет',
            message: 'Действия команды появятся в ленте автоматически.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final it in items) ...[
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                radius: 16,
                child: Row(
                  children: [
                    AppAvatar(
                      name: asStringOr(it['userName'], 'Система'),
                      avatar: asString(it['userAvatar']),
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asStringOr(it['userName'], 'Система'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_actionLabels[it['action']] ?? it['action'] ?? 'Действие'}'
                            '${it['entityName'] != null ? ' · ${it['entityName']}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      switch (BizDate.parse(it['createdAt'])) {
                        final dt? => BizDate.relative(dt),
                        null => '',
                      },
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
