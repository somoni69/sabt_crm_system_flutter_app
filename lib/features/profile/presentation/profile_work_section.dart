import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';

class _WorkSnapshot {
  const _WorkSnapshot({this.salary, this.stats, this.sales});

  final Map<String, dynamic>? salary;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? sales;
}

final profileWorkProvider = FutureProvider.autoDispose<_WorkSnapshot>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  Map<String, dynamic>? read(dynamic raw) => asMap(raw);
  final salary = read(await api.getJson('/me/salary'));
  Map<String, dynamic>? stats;
  try {
    stats = read(await api.getJson('/me/profile-stats'));
  } on ApiException {
    stats = null;
  }
  Map<String, dynamic>? sales;
  try {
    sales = read(await api.getJson('/me/sales-plan'));
  } on ApiException {
    sales = null;
  }
  return _WorkSnapshot(salary: salary, stats: stats, sales: sales);
});

class ProfileWorkSection extends ConsumerWidget {
  const ProfileWorkSection({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileWorkProvider);
    return async.when(
      loading: () =>  Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2, color: context.palette.accent),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(overline: 'РАБОТА', title: 'Мои показатели'),
            InlineError(
              compact: true,
              message: error is ApiException && error.message.trim().isNotEmpty
                  ? error.message
                  : 'Не удалось загрузить показатели',
              onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
          ],
        ),
      ),
      data: (data) {
        final cards = <Widget>[
          if (_showSalary(data.salary)) _SalaryCard(data: data.salary!),
          if (data.stats != null && asBool(data.stats!['visible']))
            _StatsCard(data: data.stats!),
          if (_showSales(user, data.sales)) _SalesCard(data: data.sales!),
        ];
        if (cards.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(overline: 'РАБОТА', title: 'Мои показатели'),
            ...cards,
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  bool _showSalary(Map<String, dynamic>? salary) =>
      salary != null &&
      asBool(salary['linked']) &&
      asMap(salary['row']) != null;

  bool _showSales(UserModel user, Map<String, dynamic>? sales) {
    final salesRole =
        user.role == 'sales_manager_smm' ||
        user.role == 'sales_manager_dev' ||
        user.secondaryRole == 'sales_manager_smm' ||
        user.secondaryRole == 'sales_manager_dev';
    return salesRole &&
        sales != null &&
        asDouble(sales['plan']) != null &&
        asDouble(sales['plan'])! > 0;
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final row = asMap(data['row']) ?? const <String, dynamic>{};
    final toPay = asDoubleOr(row['toPay'], 0);
    final paid = asBool(row['frozen']) || toPay <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Зарплата · ${data['ym'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: context.palette.text,
              ),
            ),
            const SizedBox(height: 8),
            _line(context, 'Оклад', asDoubleOr(row['salary'], 0)),
            _line(context, 'Бонус', asDoubleOr(row['bonus'], 0)),
            _line(context, 'Аванс', asDoubleOr(row['advance'], 0)),
            _line(context, 'Штраф', asDoubleOr(row['fine'], 0)),
            const SizedBox(height: 6),
            Text(
              paid ? 'Выплачено' : 'К выплате ${Money.somoni(toPay)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: paid ? context.palette.success : context.palette.text,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, double value) {
    if (value <= 0 && label != 'Оклад') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                color: context.palette.textTertiary,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Money.somoni(value),
            style:  TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: context.palette.textSecondary,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = asMap(data['level']);
    final efficiency = asMap(data['efficiency']);
    final streak = asMap(data['streak']);
    final percent = asInt(efficiency?['percent']);
    final goals = asList(data['goals'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Уровень ${asIntOr(level?['level'], 1)} · ${asIntOr(level?['points'], 0)} очков',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: context.palette.text,
              ),
            ),
            if (percent != null) ...[
              const SizedBox(height: 6),
              Text(
                'Эффективность $percent%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: percent >= 100
                      ? context.palette.success
                      : context.palette.textSecondary,
                ),
              ),
            ],
            if (streak != null)
              Text(
                'Серия ${asIntOr(streak['current'], 0)} · лучшая ${asIntOr(streak['best'], 0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12.5,
                  color: context.palette.textTertiary,
                ),
              ),
            if (goals.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final goal in goals)
                _GoalRow(
                  title: asStringOr(goal['title'], 'Цель'),
                  done: asBool(goal['done']) || asBool(goal['reached']),
                  onTap: goal['id'] == null
                      ? null
                      : () async {
                          try {
                            final done = !asBool(goal['done']);
                            await ref
                                .read(dependenciesProvider)
                                .api
                                .patchJson(
                                  '/goals/${goal['id']}',
                                  body: {'done': done},
                                );
                            ref.read(dataRevisionProvider.notifier).bump();
                          } catch (error) {
                            showProfileError(ref, error);
                          }
                        },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final plan = asDoubleOr(data['plan'], 0);
    final received = asDoubleOr(data['received'], 0);
    final pct = plan <= 0 ? 0 : ((received / plan) * 100).round().clamp(0, 999);
    final done = received >= plan && plan > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Продажи · ${data['ym'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: context.palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${Money.somoni(received)} / ${Money.somoni(plan)} · $pct%',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: done ? context.palette.success : context.palette.text,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.title, required this.done, this.onTap});

  final String title;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    height: 1.3,
                    color: context.palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: done ? context.palette.success : context.palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showProfileError(WidgetRef ref, Object error) {
  ref
      .read(dependenciesProvider)
      .banners
      .show(
        AppBanner(
          title: 'Не получилось обновить',
          message: error is ApiException ? error.message : 'Повторите попытку',
          tone: BannerTone.danger,
        ),
      );
}
