import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../projects/presentation/projects_providers.dart';
import '../data/transport_repository.dart';
import 'transport_providers.dart';

class TransportPage extends ConsumerWidget {
  const TransportPage({super.key});

  void _openRequestSheet(BuildContext context, WidgetRef ref) {
    showGlassSheet<void>(
      context: context,
      title: 'Заявка на транспорт',
      child: _CreateTransportSheet(
        onSubmitted: (projectId, amount, note) async {
          Navigator.pop(context);
          try {
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            await ref.read(transportRepositoryProvider).createRequest(
                  projectId: projectId,
                  amount: amount,
                  date: todayStr,
                  note: note,
                );
            ref.read(dataRevisionProvider.notifier).bump();
            ref.read(dependenciesProvider).banners.show(const AppBanner(
                  title: 'Заявка подана',
                  message: 'Заявка на возврат средств отправлена на утверждение.',
                  tone: BannerTone.success,
                ));
          } catch (e) {
            ref.read(dependenciesProvider).banners.show(AppBanner(
                  title: 'Ошибка',
                  message: e.toString(),
                  tone: BannerTone.danger,
                ));
          }
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Оплачено';
      case 'rejected':
        return 'Отклонено';
      case 'pending':
      default:
        return 'На рассмотрении';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transportAsync = ref.watch(myTransportProvider);

    return AppPage(
      header: AppHeader(
        title: 'Транспорт и проезд',
        subtitle: 'Компенсации за рабочие поездки',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.add_rounded,
            size: 40,
            onPressed: () => _openRequestSheet(context, ref),
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(myTransportProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: transportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить заявки',
              message: e.toString(),
              actionLabel: 'Повторить',
              onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
            data: (data) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Оплачено в этом месяце',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                              const SizedBox(height: 6),
                              Text(
                                Money.somoni(data.totalPaidThisMonth),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('На рассмотрении',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                              const SizedBox(height: 6),
                              Text(
                                Money.somoni(data.totalPending),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.warning),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (data.requests.isEmpty) ...[
                    EmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'Заявок пока нет',
                      message: 'Подайте заявку на компенсацию проезда или такси по проекту.',
                      actionLabel: 'Подать заявку',
                      onAction: () => _openRequestSheet(context, ref),
                    ),
                  ] else ...[
                    ...data.requests.map((r) {
                      final color = _statusColor(r.status);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.projectName, style: AppTypography.textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.date,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                    ),
                                    if (r.note != null && r.note!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        r.note!,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Money.somoni(r.amount),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _statusLabel(r.status),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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

class _CreateTransportSheet extends ConsumerStatefulWidget {
  const _CreateTransportSheet({required this.onSubmitted});

  final void Function(String projectId, double amount, String? note) onSubmitted;

  @override
  ConsumerState<_CreateTransportSheet> createState() => _CreateTransportSheetState();
}

class _CreateTransportSheetState extends ConsumerState<_CreateTransportSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedProjectId;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(visibleProjectsProvider);
    final activeId = _selectedProjectId ?? (projects.isNotEmpty ? projects.first.id : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (projects.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: activeId,
              dropdownColor: AppColors.surface2,
              decoration: InputDecoration(
                labelText: 'Проект',
                labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: projects
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (val) => setState(() => _selectedProjectId = val),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Сумма (сомони)',
              labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Комментарий (куда, цель поездки)',
              labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Подать заявку',
            variant: AppButtonVariant.primary,
            onPressed: () {
              final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
              if (amount <= 0 || activeId == null) return;
              widget.onSubmitted(activeId, amount, _noteCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }
}
