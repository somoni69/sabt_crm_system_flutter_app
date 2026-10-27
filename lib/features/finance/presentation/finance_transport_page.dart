import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_prompt.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/presentation/finance_providers.dart';
import '../../finance/presentation/finance_sections.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_request.dart';

final _ownerTransportProvider = FutureProvider.autoDispose<
    ({List<TransportRequestModel> pending, List<TransportRequestModel> done})>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(transportRepositoryProvider).ownerQueue(ym);
});

class FinanceTransportPage extends ConsumerWidget {
  const FinanceTransportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ym = ref.watch(selectedFinanceYmProvider);
    final async = ref.watch(_ownerTransportProvider);
    return AppPage(
      header: AppHeader(
        title: 'Транспорт сотрудникам',
        subtitle: 'Оплата и отказ по заявкам',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(_ownerTransportProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinanceMonthBar(ym: ym),
              const SizedBox(height: 14),
              async.when(
                loading: () =>  Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: context.palette.accent)),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить заявки',
                  message: error is ApiException ? error.message : 'Повторите попытку.',
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (data) {
                  if (data.pending.isEmpty && data.done.isEmpty) {
                    return const EmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'Заявок нет',
                      message: 'Новых компенсаций за проезд пока нет.',
                      compact: true,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.pending.isNotEmpty) ...[
                        const SectionHeader(overline: 'ЖДУТ', title: 'К оплате'),
                        for (final row in data.pending) _RequestCard(request: row, pending: true),
                      ],
                      if (data.done.isNotEmpty) ...[
                        const SectionHeader(overline: 'МЕСЯЦ', title: 'Уже решены'),
                        for (final row in data.done) _RequestCard(request: row, pending: false),
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

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.pending});

  final TransportRequestModel request;
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = request.status == 'paid';
    final rejected = request.status == 'rejected';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.employeeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                height: 1.25,
                color: context.palette.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${request.projectName} · ${request.date}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                height: 1.35,
                color: context.palette.textTertiary,
              ),
            ),
            if (request.note != null && request.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                request.note!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12.5,
                  height: 1.35,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              Money.somoni(request.amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.number(
                size: 16,
                weight: FontWeight.w700,
                color: done
                    ? context.palette.success
                    : rejected
                        ? context.palette.danger
                        : context.palette.text,
              ),
            ),
            if (pending) ...[
              const SizedBox(height: 12),
              AppButton(
                label: 'Оплатить',
                icon: Icons.payments_outlined,
                onPressed: () => _pay(context, ref),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Отклонить',
                variant: AppButtonVariant.danger,
                onPressed: () => _reject(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    try {
      final accounts = await ref.read(financeRepositoryProvider).accounts();
      if (!context.mounted) return;
      if (accounts.isEmpty) {
        ref.read(dependenciesProvider).banners.show(const AppBanner(
              title: 'Нет счетов',
              message: 'Сначала добавьте счёт в финансах.',
              tone: BannerTone.danger,
            ));
        return;
      }
      String accountId = accounts.first.id;
      final ok = await showGlassSheet<bool>(
        context: context,
        title: 'Оплатить проезд',
        subtitle: '${request.employeeName} · ${Money.somoni(request.amount)}',
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinanceAccountPicker(
                accounts: accounts,
                selectedId: accountId,
                onSelected: (id) => setState(() => accountId = id),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Списать со счёта',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      );
      if (ok != true) return;
      await ref.read(transportRepositoryProvider).pay(request.id, accountId);
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Не удалось оплатить',
            message: error.message,
            tone: BannerTone.danger,
          ));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showTextPrompt(
      context,
      title: 'Причина отказа',
      hint: 'Что сказать сотруднику',
      actionLabel: 'Отклонить',
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref.read(transportRepositoryProvider).reject(request.id, reason.trim());
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Не удалось отклонить',
            message: error.message,
            tone: BannerTone.danger,
          ));
    }
  }
}
