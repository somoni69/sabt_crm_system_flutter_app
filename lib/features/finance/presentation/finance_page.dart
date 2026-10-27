import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../domain/finance_models.dart';
import 'finance_providers.dart';
import 'widgets/transaction_form_sheet.dart';

class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ym = ref.watch(selectedFinanceYmProvider);
    final asyncData = ref.watch(financeOverviewProvider);

    return AppPage(
      header: AppHeader(
        title: 'Финансы',
        subtitle: 'Оплаты, счета и прибыль',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.add_rounded,
            size: 40,
            onPressed: () {
              final overview = asyncData.value;
              showGlassSheet(
                context: context,
                title: 'Новая операция',
                child: TransactionFormSheet(accounts: overview?.accounts ?? const []),
              );
            },
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(financeOverviewProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMonthNav(context, ref, ym),
              const SizedBox(height: 16),
              asyncData.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить финансы',
                  message: error.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAccountsSection(context, data),
                    const SizedBox(height: 18),
                    _buildKpiSection(context, data),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ПОСЛЕДНИЕ ОПЕРАЦИИ',
                          style: AppTypography.overline(color: AppColors.textTertiary),
                        ),
                        Text(
                          '${data.recentTransactions.length}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTransactionsList(context, data.recentTransactions),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNav(BuildContext context, WidgetRef ref, String currentYm) {
    DateTime parsed;
    try {
      parsed = DateFormat('yyyy-MM').parse(currentYm);
    } catch (_) {
      parsed = DateTime.now();
    }

    final prevYm = DateFormat('yyyy-MM').format(DateTime(parsed.year, parsed.month - 1));
    final nextYm = DateFormat('yyyy-MM').format(DateTime(parsed.year, parsed.month + 1));
    final monthName = DateFormat('LLLL yyyy', 'ru').format(parsed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppIconButton(
            icon: Icons.chevron_left_rounded,
            size: 34,
            onPressed: () => ref.read(selectedFinanceYmProvider.notifier).setYm(prevYm),
          ),
          Text(
            monthName.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          AppIconButton(
            icon: Icons.chevron_right_rounded,
            size: 34,
            onPressed: () => ref.read(selectedFinanceYmProvider.notifier).setYm(nextYm),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context, FinanceOverviewData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('СЧЕТА И БАЛАНСЫ', style: AppTypography.overline(color: AppColors.textTertiary)),
            Text(
              'Всего: ${Money.somoni(data.totalBalance)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentBright),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.accounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Счета ещё не настроены', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: data.accounts.map((acc) {
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acc.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        Money.somoni(acc.balance),
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildKpiSection(BuildContext context, FinanceOverviewData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FinanceKpiCard(
                label: 'Доход за месяц',
                amount: data.income,
                icon: Icons.arrow_downward_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FinanceKpiCard(
                label: 'Расход за месяц',
                amount: data.expense,
                icon: Icons.arrow_upward_rounded,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FinanceKpiCard(
                label: 'Чистая прибыль',
                amount: data.profit,
                icon: Icons.account_balance_rounded,
                color: data.profit >= 0 ? AppColors.accentBright : AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FinanceKpiCard(
                label: 'Ожидается к оплате',
                amount: data.receivables,
                icon: Icons.hourglass_top_rounded,
                color: AppColors.ice,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionsList(BuildContext context, List<FinanceTransaction> transactions) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('За этот месяц операций не найдено', style: TextStyle(color: AppColors.textTertiary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: transactions.map((tx) {
          final isIncome = tx.isIncome;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderSoft, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isIncome ? AppColors.successSoft : AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    size: 18,
                    color: isIncome ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.description ?? (isIncome ? 'Поступление' : 'Расход'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tx.accountName ?? 'Счёт'} • ${tx.date != null ? BizDate.dateShort(tx.date!) : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${Money.somoni(tx.amount)}',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isIncome ? AppColors.success : AppColors.text,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinanceKpiCard extends StatelessWidget {
  const _FinanceKpiCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: color),
              Text(
                Money.somoni(amount),
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
