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
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../projects/presentation/projects_providers.dart';
import '../data/transport_repository.dart';
import '../domain/transport_request.dart';
import 'transport_providers.dart';

class TransportPage extends ConsumerWidget {
  const TransportPage({super.key});

  void _openRequestSheet(BuildContext context, WidgetRef ref) {
    showGlassSheet<void>(
      context: context,
      title: 'Заявка на транспорт',
      subtitle: 'Компенсация расходов на такси и служебный проезд',
      child: const _CreateTransportSheet(),
    );
  }

  Future<void> _cancelRequest(
    BuildContext context,
    WidgetRef ref,
    TransportRequestModel request,
  ) async {
    await showConfirmSheet(
      context: context,
      title: 'Отозвать заявку?',
      message:
          'Вы действительно хотите отменить заявку на сумму ${Money.somoni(request.amount)} по проекту «${request.projectName}»?',
      confirmLabel: 'Отозвать',
      danger: true,
      onConfirm: () async {
        try {
          await ref.read(transportRepositoryProvider).cancelRequest(request.id);
          ref.read(dataRevisionProvider.notifier).bump();
          if (context.mounted) {
            ref.read(dependenciesProvider).banners.show(
                  const AppBanner(
                    title: 'Заявка отозвана',
                    message: 'Заявка на компенсацию успешно отменена.',
                    tone: BannerTone.info,
                  ),
                );
          }
        } catch (e) {
          if (context.mounted) {
            ref.read(dependenciesProvider).banners.show(
                  AppBanner(
                    title: 'Ошибка',
                    message: e.toString(),
                    tone: BannerTone.danger,
                  ),
                );
          }
        }
      },
    );
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
            tooltip: 'Подать заявку',
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
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 72, radius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 72, radius: 12)),
                  ],
                ),
                SizedBox(height: 20),
                SkeletonBox(height: 80, radius: 12),
                SizedBox(height: 10),
                SkeletonBox(height: 80, radius: 12),
              ],
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
                  Row(
                    children: [
                      Expanded(
                        child: _TransportStatCard(
                          label: 'Оплачено в этом месяце',
                          value: Money.somoni(data.totalPaidThisMonth),
                          color: context.palette.success,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TransportStatCard(
                          label: 'На рассмотрении',
                          value: Money.somoni(data.totalPending),
                          color: context.palette.warning,
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (data.requests.isEmpty) ...[
                    const EmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'Заявок пока нет',
                      message:
                          'Подайте заявку на компенсацию проезда или такси по проекту.',
                    ),
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: AppButton(
                          label: 'Подать заявку',
                          icon: Icons.add_rounded,
                          onPressed: () => _openRequestSheet(context, ref),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    const SectionHeader(
                      title: 'История заявок',
                      overline: 'КОМПЕНСАЦИИ',
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                    ),
                    for (final r in data.requests)
                      _TransportRequestCard(
                        request: r,
                        onCancel: () => _cancelRequest(context, ref, r),
                      ),
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

class _TransportStatCard extends StatelessWidget {
  const _TransportStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 15, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportRequestCard extends StatelessWidget {
  const _TransportRequestCard({
    required this.request,
    required this.onCancel,
  });

  final TransportRequestModel request;
  final VoidCallback onCancel;

  ChipTone _chipTone(String status) => switch (status.toLowerCase()) {
    'paid' => ChipTone.success,
    'rejected' => ChipTone.danger,
    'pending' => ChipTone.warning,
    _ => ChipTone.neutral,
  };

  String _statusLabel(String status) => switch (status.toLowerCase()) {
    'paid' => 'Оплачено',
    'rejected' => 'Отклонено',
    'pending' => 'На рассмотрении',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPending = request.status.toLowerCase() == 'pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: palette.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.date,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money.somoni(request.amount),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppChip(
                      label: _statusLabel(request.status),
                      tone: _chipTone(request.status),
                      dot: true,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
            if (request.note != null && request.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.borderSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: palette.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.note!.trim(),
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.5,
                          height: 1.35,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.danger,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text(
                    'Отозвать заявку',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateTransportSheet extends ConsumerStatefulWidget {
  const _CreateTransportSheet();

  @override
  ConsumerState<_CreateTransportSheet> createState() =>
      _CreateTransportSheetState();
}

class _CreateTransportSheetState extends ConsumerState<_CreateTransportSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedProjectId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String? activeId) async {
    final rawAmount =
        _amountCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.');
    final amount = double.tryParse(rawAmount) ?? 0;

    if (activeId == null || activeId.isEmpty) {
      setState(() => _error = 'Выберите проект для привязки расходов');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Укажите сумму поездки больше нуля');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await ref.read(transportRepositoryProvider).createRequest(
            projectId: activeId,
            amount: amount,
            date: todayStr,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) {
        Navigator.of(context).pop();
        ref.read(dependenciesProvider).banners.show(
              const AppBanner(
                title: 'Заявка подана',
                message:
                    'Заявка на возврат средств отправлена на утверждение.',
                tone: BannerTone.success,
              ),
            );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(visibleProjectsProvider);
    final activeId =
        _selectedProjectId ?? (projects.isNotEmpty ? projects.first.id : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        if (projects.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.palette.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.palette.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Нет доступных проектов для привязки расходов.',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12.5,
                      color: context.palette.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          const FormSectionLabel('Проект'),
          AppSelectField<String>(
            value: activeId,
            items: projects.map((p) => p.id).toList(),
            icon: Icons.folder_outlined,
            labelOf: (id) => projects
                .firstWhere((p) => p.id == id, orElse: () => projects.first)
                .name,
            onChanged: (val) => setState(() => _selectedProjectId = val),
          ),
          const SizedBox(height: 12),
        ],
        const FormSectionLabel('Сумма (сомони)'),
        TextField(
          controller: _amountCtrl,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: '0.00',
            prefixIcon: Icon(Icons.payments_outlined, size: 19),
            suffixText: 'сомони',
          ),
        ),
        const SizedBox(height: 12),
        const FormSectionLabel('Комментарий (куда, цель поездки)'),
        TextField(
          controller: _noteCtrl,
          enabled: !_busy,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            height: 1.4,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Например: Такси к клиенту на согласование договора',
            prefixIcon: Icon(Icons.description_outlined, size: 19),
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: _busy ? 'Отправка...' : 'Подать заявку',
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: _busy ? null : () => _submit(activeId),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
