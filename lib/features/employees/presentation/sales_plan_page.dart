import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

class _SalesYm extends Notifier<String> {
  @override
  String build() => DateFormat('yyyy-MM').format(DateTime.now());

  void set(String ym) => state = ym;
}

final _salesYmProvider = NotifierProvider.autoDispose<_SalesYm, String>(
  _SalesYm.new,
);

final _salesPlansProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(_salesYmProvider);
  final res = await ref
      .watch(dependenciesProvider)
      .api
      .getJson('/sales-plans', query: {'ym': ym});
  return asMap(res) ?? const {};
});

class SalesPlanPage extends ConsumerWidget {
  const SalesPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ym = ref.watch(_salesYmProvider);
    final async = ref.watch(_salesPlansProvider);
    DateTime parsed;
    try {
      parsed = DateFormat('yyyy-MM').parse(ym);
    } catch (_) {
      parsed = DateTime.now();
    }
    final label = DateFormat('LLLL yyyy', 'ru').format(parsed);

    return AppPage(
      header: AppHeader(
        title: 'План продаж',
        subtitle: 'Сумма месяца для менеджеров',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(_salesPlansProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: context.palette.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.palette.borderSoft),
                ),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.chevron_left_rounded,
                      size: 44,
                      tooltip: 'Предыдущий месяц',
                      onPressed: () => ref
                          .read(_salesYmProvider.notifier)
                          .set(
                            DateFormat(
                              'yyyy-MM',
                            ).format(DateTime(parsed.year, parsed.month - 1)),
                          ),
                    ),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontFamily: AppTypography.family,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: context.palette.text,
                        ),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.chevron_right_rounded,
                      size: 44,
                      tooltip: 'Следующий месяц',
                      onPressed: () => ref
                          .read(_salesYmProvider.notifier)
                          .set(
                            DateFormat(
                              'yyyy-MM',
                            ).format(DateTime(parsed.year, parsed.month + 1)),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Как в прошлом месяце',
                variant: AppButtonVariant.secondary,
                compact: true,
                icon: Icons.copy_rounded,
                onPressed: () => _copy(ref, ym),
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () =>  Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: context.palette.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'План не загрузился',
                  message: error is ApiException
                      ? error.message
                      : 'Повторите попытку.',
                  actionLabel: 'Повторить',
                  onAction: () =>
                      ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (data) {
                  final managers = asList(data['managers'])
                      .map(asMap)
                      .whereType<Map<String, dynamic>>()
                      .toList();
                  if (managers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.flag_outlined,
                      title: 'Менеджеров нет',
                      message: 'В команде нет менеджеров продаж.',
                      compact: true,
                    );
                  }
                  return Column(
                    children: [
                      for (final manager in managers)
                        _ManagerPlan(ym: ym, manager: manager),
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

  Future<void> _copy(WidgetRef ref, String ym) async {
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson('/sales-plans/copy', body: {'ym': ym});
      ref.read(dataRevisionProvider.notifier).bump();
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            const AppBanner(
              title: 'План скопирован',
              message: 'Пустые строки взяли сумму прошлого месяца.',
              tone: BannerTone.success,
            ),
          );
    } on ApiException catch (error) {
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            AppBanner(
              title: 'Не удалось скопировать',
              message: error.message,
              tone: BannerTone.danger,
            ),
          );
    }
  }
}

class _ManagerPlan extends ConsumerStatefulWidget {
  const _ManagerPlan({required this.ym, required this.manager});

  final String ym;
  final Map<String, dynamic> manager;

  @override
  ConsumerState<_ManagerPlan> createState() => _ManagerPlanState();
}

class _ManagerPlanState extends ConsumerState<_ManagerPlan> {
  late final TextEditingController _amount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = asDouble(widget.manager['plan']);
    _amount = TextEditingController(
      text: plan == null || plan == 0 ? '' : plan.round().toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _ManagerPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    final plan = asDouble(widget.manager['plan']);
    final next = plan == null || plan == 0 ? '' : plan.round().toString();
    if (_amount.text != next && !_saving) _amount.text = next;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _amount.text.replaceAll(RegExp(r'[^\d]'), '');
    final amount = digits.isEmpty ? 0 : int.parse(digits);
    setState(() => _saving = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .putJson(
            '/sales-plans/${widget.manager['id']}',
            body: {'ym': widget.ym, 'amount': amount},
          );
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            AppBanner(
              title: 'План не сохранился',
              message: error.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final received = asDoubleOr(widget.manager['received'], 0);
    final plan = asDouble(widget.manager['plan']) ?? 0;
    final role = widget.manager['role'] == 'sales_manager_dev'
        ? 'Разработка'
        : 'SMM';
    final paceMet = plan > 0 && received >= plan;
    final field = TextField(
      controller: _amount,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style:  TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 15,
        color: context.palette.text,
        fontFeatures: AppTypography.tabular,
      ),
      decoration: const InputDecoration(labelText: 'План, сомони'),
      onSubmitted: (_) => _save(),
    );
    final saveButton = AppButton(
      label: 'Сохранить',
      compact: true,
      loading: _saving,
      onPressed: _saving ? null : _save,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asStringOr(widget.manager['name'], 'Менеджер'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: context.palette.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$role · получено ${Money.somoni(received)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                height: 1.35,
                color: paceMet ? context.palette.success : context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                if (!width.isFinite || width < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [field, const SizedBox(height: 8), saveButton],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 8),
                    SizedBox(width: 148, child: saveButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
