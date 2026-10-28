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
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../data/finance_repository.dart';
import 'finance_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. ПЛАНИРОВАНИЕ (/finance/planning)
// ═══════════════════════════════════════════════════════════════════════════

final _financePlanningProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String ym, String scenario})>(
        (ref, args) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final planned = asList(await api.getJson('/finance/planned-payments'))
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .toList();
  final projects = asList(await api.getJson('/finance/projects'))
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .toList();
  final debts = asList(await api.getJson('/finance/debts'))
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .toList();
  Map<String, dynamic> forecast = const {};
  try {
    final year = args.ym.split('-').first;
    forecast = asMap(
          await api.getJson(
            '/finance/forecast',
            query: {
              'start': '$year-01',
              'months': 12,
              'scenario': args.scenario,
            },
          ),
        ) ??
        const {};
  } catch (_) {}
  return {
    'planned': planned,
    'projects': projects,
    'debts': debts,
    'forecast': forecast,
  };
});

class FinancePlanningPage extends ConsumerStatefulWidget {
  const FinancePlanningPage({super.key});

  @override
  ConsumerState<FinancePlanningPage> createState() =>
      _FinancePlanningPageState();
}

class _FinancePlanningPageState extends ConsumerState<FinancePlanningPage> {
  bool _showForecast = false;
  String _scenario = 'base'; // 'conservative' | 'base' | 'optimistic'

  Future<void> _togglePlanned(
    Map<String, dynamic> row,
    String title,
  ) async {
    final id = asStringOr(row['id'], '');
    if (id.isEmpty) return;
    final status = asStringOr(row['status'], 'expected');
    final repo = ref.read(financeRepositoryProvider);
    final api = ref.read(dependenciesProvider).api;

    if (status == 'received') {
      try {
        await api.postJson('/finance/planned-payments/$id/unreceive', body: {});
        ref.read(dataRevisionProvider.notifier).bump();
      } on ApiException catch (e) {
        ref.read(dependenciesProvider).banners.show(
              AppBanner(
                title: 'Ошибка',
                message: e.message,
                tone: BannerTone.danger,
              ),
            );
      }
      return;
    }

    final accounts = await repo.accounts();
    if (accounts.isEmpty) {
      ref.read(dependenciesProvider).banners.show(
            const AppBanner(
              title: 'Нет счетов',
              message: 'Сначала создайте счёт в настройках финансов.',
              tone: BannerTone.warning,
            ),
          );
      return;
    }

    try {
      await repo.receivePlanned(
        plannedId: id,
        accountId: accounts.first.id,
        date: BizDate.todayKey(),
        amount: asDoubleOr(row['amount'], 0),
      );
      ref.read(dataRevisionProvider.notifier).bump();
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Отмечено',
              message: '$title отмечено выполненным.',
              tone: BannerTone.success,
            ),
          );
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
  Widget build(BuildContext context) {
    final ym = ref.watch(selectedFinanceYmProvider);
    final async = ref.watch(
      _financePlanningProvider((ym: ym, scenario: _scenario)),
    );
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Планирование',
        subtitle: 'Платёжный календарь и прогноз',
        onBack: () => context.pop(),
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
              Row(
                children: [
                  Expanded(
                    child: AppFilterChip(
                      label: 'Платёжный календарь',
                      active: !_showForecast,
                      onTap: () => setState(() => _showForecast = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterChip(
                      label: 'Прогноз 12 мес.',
                      active: _showForecast,
                      onTap: () => setState(() => _showForecast = true),
                    ),
                  ),
                ],
              ),
              if (_showForecast) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final sc in const [
                        ('conservative', 'Осторожный'),
                        ('base', 'Базовый'),
                        ('optimistic', 'Оптимистичный'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppFilterChip(
                            label: sc.$2,
                            active: _scenario == sc.$1,
                            onTap: () => setState(() => _scenario = sc.$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              async.when(
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
                data: (data) {
                  if (_showForecast) {
                    final forecast =
                        asMap(data['forecast']) ?? const <String, dynamic>{};
                    final months = asList(forecast['months'] ?? forecast['rows'])
                        .map(asMap)
                        .whereType<Map<String, dynamic>>()
                        .toList();
                    if (months.isEmpty) {
                      return const EmptyState(
                        icon: Icons.trending_up_rounded,
                        title: 'Прогноз пуст',
                        message:
                            'Добавьте плановые доходы и расходы для расчёта прогноза.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final m in months) ...[
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            radius: 16,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asStringOr(m['ym'] ?? m['month'], ''),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: palette.text,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '+${Money.somoni(asDoubleOr(m['income'], 0))} · −${Money.somoni(asDoubleOr(m['expense'], 0))}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Money.somoni(
                                    asDoubleOr(
                                      m['net'] ?? m['balance'] ?? m['profit'],
                                      asDoubleOr(m['income'], 0) -
                                          asDoubleOr(m['expense'], 0),
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: asDoubleOr(
                                              m['net'] ??
                                                  m['balance'] ??
                                                  m['profit'],
                                              0,
                                            ) >=
                                            0
                                        ? palette.success
                                        : palette.danger,
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
                  }

                  final projects = <String, String>{
                    for (final p in (data['projects']
                            as List<Map<String, dynamic>>? ??
                        const []))
                      asStringOr(p['id'], ''): asStringOr(p['name'], 'Проект'),
                  };
                  final debts = <String, String>{
                    for (final d
                        in (data['debts'] as List<Map<String, dynamic>>? ??
                            const []))
                      asStringOr(d['id'], ''): asStringOr(d['name'], 'Долг'),
                  };
                  final planned =
                      (data['planned'] as List<Map<String, dynamic>>? ??
                              const [])
                          .where((p) {
                    final pym = asStringOr(p['dueDate'], '').length >= 7
                        ? asStringOr(p['dueDate'], '').substring(0, 7)
                        : asStringOr(p['ym'], '');
                    return pym == ym;
                  }).toList();

                  if (planned.isEmpty) {
                    return const EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Плановых платежей за месяц нет',
                      message: 'Выберите другой месяц или переключитесь на прогноз.',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in planned) ...[
                        Builder(
                          builder: (context) {
                            final isIncome = p['projectId'] != null;
                            final done = p['status'] == 'received';
                            final title = isIncome
                                ? (projects[asStringOr(p['projectId'], '')] ??
                                    'Оплата по проекту')
                                : (debts[asStringOr(p['debtId'], '')] ??
                                    'Погашение долга');
                            final due = asStringOr(p['dueDate'], ym);
                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              radius: 16,
                              onTap: () => _togglePlanned(p, title),
                              child: Row(
                                children: [
                                  Icon(
                                    done
                                        ? Icons.check_circle_rounded
                                        : (isIncome
                                            ? Icons.south_west_rounded
                                            : Icons.north_east_rounded),
                                    size: 20,
                                    color: done
                                        ? palette.success
                                        : (isIncome
                                            ? palette.accentBright
                                            : palette.warning),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: palette.text,
                                          ),
                                        ),
                                        Text(
                                          'Срок: $due · ${done ? 'Выполнено' : 'Запланировано'}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: palette.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '−'}${Money.somoni(asDoubleOr(p['amount'], 0))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: isIncome
                                          ? palette.success
                                          : palette.text,
                                      fontFeatures: AppTypography.tabular,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

// ═══════════════════════════════════════════════════════════════════════════
// 2. ИНВЕНТАРЬ (/finance/inventory)
// ═══════════════════════════════════════════════════════════════════════════

final financeAssetsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw =
      await ref.watch(dependenciesProvider).api.getJson('/finance/assets');
  return asList(raw).map(asMap).whereType<Map<String, dynamic>>().toList();
});

class FinanceInventoryPage extends ConsumerStatefulWidget {
  const FinanceInventoryPage({super.key});

  @override
  ConsumerState<FinanceInventoryPage> createState() =>
      _FinanceInventoryPageState();
}

class _FinanceInventoryPageState extends ConsumerState<FinanceInventoryPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAssetDialog([Map<String, dynamic>? existing]) async {
    final nameCtrl =
        TextEditingController(text: asStringOr(existing?['name'], ''));
    final catCtrl =
        TextEditingController(text: asStringOr(existing?['category'], 'Техника'));
    final priceCtrl = TextEditingController(
      text: existing != null ? '${asDoubleOr(existing['price'], 0)}' : '',
    );
    final monthsCtrl = TextEditingController(
      text: existing != null ? '${asIntOr(existing['serviceMonths'], 36)}' : '36',
    );
    final assigneeCtrl =
        TextEditingController(text: asStringOr(existing?['assignee'], ''));
    var status = asStringOr(existing?['status'], 'in_use');

    final saved = await showGlassSheet<String>(
      context: context,
      title: existing == null ? 'Новое оборудование' : 'Оборудование',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Название (Sony A7 IV, стол…)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: catCtrl,
                    decoration: const InputDecoration(labelText: 'Категория'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: assigneeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Ответственный'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Цена, сомони'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: monthsCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Срок службы, мес.'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final st in const [
                    ('in_use', 'В работе'),
                    ('repair', 'В ремонте'),
                    ('written_off', 'Списано'),
                    ('sold', 'Продано'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AppFilterChip(
                        label: st.$2,
                        active: status == st.$1,
                        onTap: () => setState(() => status = st.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (existing != null) ...[
                  Expanded(
                    child: AppButton(
                      label: 'Удалить',
                      variant: ButtonVariant.danger,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop('delete'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: AppButton(
                    label: 'Сохранить',
                    expand: true,
                    onPressed: () => Navigator.of(context).pop('save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final cat = catCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final months = int.tryParse(monthsCtrl.text) ?? 36;
    final assignee = assigneeCtrl.text.trim();
    nameCtrl.dispose();
    catCtrl.dispose();
    priceCtrl.dispose();
    monthsCtrl.dispose();
    assigneeCtrl.dispose();

    final api = ref.read(dependenciesProvider).api;
    try {
      if (saved == 'delete' && existing != null) {
        await api.deleteJson('/finance/assets/${existing['id']}');
        ref.invalidate(financeAssetsProvider);
      } else if (saved == 'save' && name.isNotEmpty) {
        final body = <String, dynamic>{
          'name': name,
          if (cat.isNotEmpty) 'category': cat,
          'price': price,
          'serviceMonths': months,
          'status': status,
          if (assignee.isNotEmpty) 'assignee': assignee,
        };
        if (existing != null) {
          await api.patchJson('/finance/assets/${existing['id']}', body: body);
        } else {
          await api.postJson('/finance/assets', body: body);
        }
        ref.invalidate(financeAssetsProvider);
      }
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
  Widget build(BuildContext context) {
    final async = ref.watch(financeAssetsProvider);
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Инвентарь',
        subtitle: 'Оборудование и амортизация',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.add_rounded,
            size: 40,
            onPressed: () => _openAssetDialog(),
          ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(financeAssetsProvider);
        await ref.read(financeAssetsProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSearchField(
                controller: _searchCtrl,
                hint: 'Поиск: название, серийник, ответственный…',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                ),
                error: (err, _) => InlineError(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(financeAssetsProvider),
                ),
                data: (assets) {
                  final active = assets.where(
                    (a) => a['status'] == 'in_use' || a['status'] == 'repair',
                  );
                  final parkPrice = active.fold<double>(
                    0,
                    (s, a) => s + asDoubleOr(a['price'], 0),
                  );
                  final parkResidual = active.fold<double>(
                    0,
                    (s, a) => s + asDoubleOr(a['residual'], 0),
                  );
                  final monthlyDep = active.fold<double>(
                    0,
                    (s, a) => s + asDoubleOr(a['monthlyDep'], 0),
                  );

                  final filtered = _query.isEmpty
                      ? assets
                      : assets.where((a) {
                          final hay =
                              '${a['name'] ?? ''} ${a['serial'] ?? ''} ${a['assignee'] ?? ''} ${a['category'] ?? ''}'
                                  .toLowerCase();
                          return hay.contains(_query);
                        }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _FinMetricTile(
                              label: 'Стоимость парка',
                              value: Money.somoni(parkPrice),
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FinMetricTile(
                              label: 'Остаточная',
                              value: Money.somoni(parkResidual),
                              color: palette.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _FinMetricTile(
                              label: 'Амортизация/мес.',
                              value: Money.somoni(monthlyDep),
                              color: palette.warning,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FinMetricTile(
                              label: 'Единиц в работе',
                              value: '${active.length}',
                              color: palette.accentBright,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Оборудование не найдено',
                          message:
                              'Добавьте технику или мебель кнопкой «+» вверху.',
                          compact: true,
                        )
                      else
                        for (final a in filtered) ...[
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            radius: 16,
                            onTap: () => _openAssetDialog(a),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asStringOr(a['name'], 'Оборудование'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: palette.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${a['category'] ?? 'Без категории'}'
                                        '${a['assignee'] != null ? ' · ${a['assignee']}' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: palette.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Money.somoni(asDoubleOr(a['price'], 0)),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: palette.text,
                                        fontFeatures: AppTypography.tabular,
                                      ),
                                    ),
                                    Text(
                                      'ост. ${Money.somoni(asDoubleOr(a['residual'], 0))}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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

class _FinMetricTile extends StatelessWidget {
  const _FinMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(13),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.overline(color: palette.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. АКТИВНОСТЬ ФИНАНСОВ (/finance/activity)
// ═══════════════════════════════════════════════════════════════════════════

final financeActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw = await ref
      .watch(dependenciesProvider)
      .api
      .getJson('/finance/activity', query: {'limit': 60, 'offset': 0});
  final map = asMap(raw);
  final rows = map != null ? asList(map['rows'] ?? map['items']) : asList(raw);
  return rows.map(asMap).whereType<Map<String, dynamic>>().toList();
});

class FinanceActivityPage extends ConsumerWidget {
  const FinanceActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeActivityProvider);
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Активность финансов',
        subtitle: 'Журнал изменений и операций',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            onPressed: () => ref.invalidate(financeActivityProvider),
          ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(financeActivityProvider);
        await ref.read(financeActivityProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: async.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            ),
            error: (err, _) => InlineError(
              message: err.toString(),
              onRetry: () => ref.invalidate(financeActivityProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Записей пока нет',
                  message:
                      'Здесь отображаются все изменения в разделе «Финансы».',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in rows) ...[
                    AppCard(
                      padding: const EdgeInsets.all(13),
                      radius: 16,
                      child: Row(
                        children: [
                          SurfaceIcon(
                            icon: Icons.history_edu_rounded,
                            color: palette.accentBright,
                            size: 38,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asStringOr(r['action'], 'Изменение'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${asStringOr(r['userName'], 'Система')} · ${switch (BizDate.parse(r['createdAt'])) { final dt? => BizDate.relative(dt), null => '—' }}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: palette.textTertiary,
                                  ),
                                ),
                              ],
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
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. НАСТРОЙКИ ФИНАНСОВ (/finance/settings)
// ═══════════════════════════════════════════════════════════════════════════

final _financeSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final accounts = asList(await api.getJson('/finance/accounts'))
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .toList();
  final categories = asList(await api.getJson('/finance/categories'))
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .toList();
  List<Map<String, dynamic>> backups = const [];
  try {
    backups = asList(await api.getJson('/finance/backups'))
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (_) {}
  return {
    'accounts': accounts,
    'categories': categories,
    'backups': backups,
  };
});

class FinanceSettingsPage extends ConsumerStatefulWidget {
  const FinanceSettingsPage({super.key});

  @override
  ConsumerState<FinanceSettingsPage> createState() =>
      _FinanceSettingsPageState();
}

class _FinanceSettingsPageState extends ConsumerState<FinanceSettingsPage> {
  String _tab = 'accounts'; // 'accounts' | 'categories' | 'backups'
  bool _busy = false;

  Future<void> _createAccount() async {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    final ok = await showGlassSheet<bool>(
      context: context,
      title: 'Новый счёт',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Название счёта (Касса, Алиф, Душанбе Сити…)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: balanceCtrl,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Начальный баланс, сомони'),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Создать счёт',
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final startBalance =
        double.tryParse(balanceCtrl.text.replaceAll(',', '.')) ?? 0;
    nameCtrl.dispose();
    balanceCtrl.dispose();
    if (ok != true || name.isEmpty) return;

    try {
      await ref.read(dependenciesProvider).api.postJson(
        '/finance/accounts',
        body: {'name': name, 'startBalance': startBalance},
      );
      ref.invalidate(_financeSettingsProvider);
      ref.read(dataRevisionProvider.notifier).bump();
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

  Future<void> _createCategory() async {
    final nameCtrl = TextEditingController();
    var type = 'expense';
    final ok = await showGlassSheet<bool>(
      context: context,
      title: 'Новая категория',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Название категории'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppFilterChip(
                    label: 'Расход',
                    active: type == 'expense',
                    onTap: () => setState(() => type = 'expense'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppFilterChip(
                    label: 'Доход',
                    active: type == 'income',
                    onTap: () => setState(() => type = 'income'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Создать категорию',
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || name.isEmpty) return;

    try {
      await ref.read(dependenciesProvider).api.postJson(
        '/finance/categories',
        body: {'name': name, 'type': type},
      );
      ref.invalidate(_financeSettingsProvider);
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

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson('/finance/backups', body: {});
      ref.invalidate(_financeSettingsProvider);
      ref.read(dependenciesProvider).banners.show(
            const AppBanner(
              title: 'Снимок создан',
              message: 'Резервная копия финансовых данных сохранена.',
              tone: BannerTone.success,
            ),
          );
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_financeSettingsProvider);
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Настройки финансов',
        subtitle: 'Счета, категории и снимки данных',
        onBack: () => context.pop(),
        actions: [
          if (_tab == 'accounts')
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              onPressed: _createAccount,
            )
          else if (_tab == 'categories')
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              onPressed: _createCategory,
            ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(_financeSettingsProvider);
        await ref.read(_financeSettingsProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppFilterChip(
                      label: 'Счета',
                      active: _tab == 'accounts',
                      onTap: () => setState(() => _tab = 'accounts'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterChip(
                      label: 'Категории',
                      active: _tab == 'categories',
                      onTap: () => setState(() => _tab = 'categories'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterChip(
                      label: 'Бэкапы',
                      active: _tab == 'backups',
                      onTap: () => setState(() => _tab = 'backups'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                ),
                error: (err, _) => InlineError(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(_financeSettingsProvider),
                ),
                data: (data) {
                  if (_tab == 'accounts') {
                    final accounts =
                        data['accounts'] as List<Map<String, dynamic>>? ??
                            const [];
                    if (accounts.isEmpty) {
                      return const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Счетов нет',
                        message: 'Добавьте первый счёт кнопкой «+».',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final a in accounts) ...[
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            radius: 16,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 20,
                                  color: palette.accentBright,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asStringOr(a['name'], 'Счёт'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: palette.text,
                                        ),
                                      ),
                                      Text(
                                        asBool(a['archived'])
                                            ? 'В архиве'
                                            : 'Активный счёт',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: palette.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Money.somoni(
                                    asDoubleOr(
                                      a['balance'] ?? a['startBalance'],
                                      0,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: palette.text,
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
                  }

                  if (_tab == 'categories') {
                    final categories =
                        data['categories'] as List<Map<String, dynamic>>? ??
                            const [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final c in categories) ...[
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            radius: 16,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    asStringOr(c['name'], 'Категория'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      color: palette.text,
                                    ),
                                  ),
                                ),
                                AppChip(
                                  label: c['type'] == 'income'
                                      ? 'Доход'
                                      : 'Расход',
                                  tone: c['type'] == 'income'
                                      ? ChipTone.success
                                      : ChipTone.warning,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  }

                  final backups =
                      data['backups'] as List<Map<String, dynamic>>? ??
                          const [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: 'Создать страховочный снимок',
                        icon: Icons.backup_outlined,
                        busy: _busy,
                        expand: true,
                        onPressed: _createBackup,
                      ),
                      const SizedBox(height: 14),
                      if (backups.isEmpty)
                        const EmptyState(
                          icon: Icons.cloud_done_outlined,
                          title: 'Снимков пока нет',
                          message:
                              'Создайте снимок перед крупными изменениями.',
                          compact: true,
                        )
                      else
                        for (final b in backups) ...[
                          AppCard(
                            padding: const EdgeInsets.all(14),
                            radius: 16,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restore_rounded,
                                  size: 20,
                                  color: palette.accentBright,
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asStringOr(
                                          b['note'] ?? b['kind'],
                                          'Снимок финансов',
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: palette.text,
                                        ),
                                      ),
                                      Text(
                                        switch (BizDate.parse(b['createdAt'])) {
                                          final dt? => BizDate.relative(dt),
                                          null => '—',
                                        },
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: palette.textTertiary,
                                        ),
                                      ),
                                    ],
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. КАРТОЧКА ЗАРПЛАТЫ СОТРУДНИКА (/finance/salary/:id)
// ═══════════════════════════════════════════════════════════════════════════

final financeEmployeeSalaryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  final raw = await ref
      .watch(dependenciesProvider)
      .api
      .getJson('/finance/employees/$id/payouts', query: {'scope': 'all'});
  return asMap(raw) ?? const <String, dynamic>{};
});

class FinanceEmployeeSalaryPage extends ConsumerStatefulWidget {
  const FinanceEmployeeSalaryPage({super.key, required this.employeeId});

  final String employeeId;

  @override
  ConsumerState<FinanceEmployeeSalaryPage> createState() =>
      _FinanceEmployeeSalaryPageState();
}

class _FinanceEmployeeSalaryPageState
    extends ConsumerState<FinanceEmployeeSalaryPage> {
  Future<void> _addAdjustment(String kind, String title) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ym = ref.read(selectedFinanceYmProvider);

    final ok = await showGlassSheet<bool>(
      context: context,
      title: title,
      subtitle: 'Месяц: $ym',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Сумма, сомони'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Комментарий'),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Сохранить',
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final note = noteCtrl.text.trim();
    amountCtrl.dispose();
    noteCtrl.dispose();
    if (ok != true || amount <= 0) return;

    try {
      await ref.read(dependenciesProvider).api.postJson(
        '/finance/employees/${widget.employeeId}/deduction',
        body: {
          'kind': kind,
          'ym': ym,
          'amount': amount,
          if (note.isNotEmpty) 'note': note,
        },
      );
      ref.invalidate(financeEmployeeSalaryProvider(widget.employeeId));
      ref.read(dataRevisionProvider.notifier).bump();
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
  Widget build(BuildContext context) {
    final async = ref.watch(financeEmployeeSalaryProvider(widget.employeeId));
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'История зарплаты',
        subtitle: 'Начисления, бонусы и удержания',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.invalidate(financeEmployeeSalaryProvider(widget.employeeId));
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: async.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            ),
            error: (err, _) => InlineError(
              message: err.toString(),
              onRetry: () => ref.invalidate(
                financeEmployeeSalaryProvider(widget.employeeId),
              ),
            ),
            data: (data) {
              final emp = asMap(data['employee']) ?? data;
              final months = asList(data['months'] ?? data['payouts'] ?? data['rows'])
                  .map(asMap)
                  .whereType<Map<String, dynamic>>()
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    radius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asStringOr(emp['name'], 'Сотрудник'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Оклад: ${Money.somoni(asDoubleOr(emp['salary'], 0))}',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: '+ Бонус',
                                variant: ButtonVariant.secondary,
                                compact: true,
                                onPressed: () =>
                                    _addAdjustment('bonus', 'Начислить бонус'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppButton(
                                label: 'Штраф',
                                variant: ButtonVariant.danger,
                                compact: true,
                                onPressed: () =>
                                    _addAdjustment('fine', 'Начислить штраф'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppButton(
                                label: 'Отпускные',
                                variant: ButtonVariant.ghost,
                                compact: true,
                                onPressed: () => _addAdjustment(
                                  'vacation',
                                  'Начислить отпускные',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(
                    overline: 'ПО МЕСЯЦАМ',
                    title: 'История начислений',
                  ),
                  if (months.isEmpty)
                    const EmptyState(
                      icon: Icons.payments_outlined,
                      title: 'Истории пока нет',
                      message: 'Выплаты по месяцам отобразятся здесь.',
                      compact: true,
                    )
                  else
                    for (final m in months) ...[
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        radius: 16,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asStringOr(m['ym'], ''),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: palette.text,
                                    ),
                                  ),
                                  Text(
                                    'Оклад ${Money.somoni(asDoubleOr(m['salary'], 0))}'
                                    '${asDoubleOr(m['bonus'], 0) > 0 ? ' · бонус ${Money.somoni(asDoubleOr(m['bonus'], 0))}' : ''}'
                                    '${asDoubleOr(m['fine'], 0) > 0 ? ' · штраф ${Money.somoni(asDoubleOr(m['fine'], 0))}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.somoni(
                                asDoubleOr(m['paid'] ?? m['toPay'], 0),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
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
          ),
        ),
      ],
    );
  }
}
