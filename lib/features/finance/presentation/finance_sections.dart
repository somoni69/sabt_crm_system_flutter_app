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
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../data/finance_repository.dart';
import '../domain/finance_models.dart';
import 'finance_providers.dart';

class FinanceIncomePage extends ConsumerWidget {
  const FinanceIncomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeIncomeProvider);
    return _FinanceScaffold(
      title: 'Доход',
      subtitle: 'Направления и ожидаемые оплаты',
      onRefresh: () => ref.read(financeIncomeProvider.future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.payments_outlined,
              title: 'Направлений нет',
              message: 'За этот месяц финансы не вернули направления дохода.',
              compact: true,
            );
          }
          return Column(
            children: [
              for (final row in rows)
                _PayCard(
                  title: row.label,
                  subtitle: '${row.projectCount} проектов',
                  amount: row.expected > 0 ? row.expected : row.received,
                  amountLabel: row.expected > 0 ? 'ожидается' : 'получено',
                  late: false,
                  done: row.expected <= 0 && row.received > 0,
                  onTap: () => context.push('/finance/income/${row.direction}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class FinanceIncomeDetailPage extends ConsumerWidget {
  const FinanceIncomeDetailPage({super.key, required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeIncomeRowsProvider(direction));
    final title = FinanceDirectionCard.labels[direction] ?? 'Доход';
    return _FinanceScaffold(
      title: title,
      subtitle: 'Отметить оплату клиента',
      onRefresh: () => ref.read(financeIncomeRowsProvider(direction).future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Ожидаемых оплат нет',
              message: 'В этом месяце по направлению нечего принимать.',
              compact: true,
            );
          }
          return Column(
            children: [
              for (final row in rows)
                _PayCard(
                  title: row.name,
                  subtitle: row.dueDate == null
                      ? 'К получению'
                      : 'Срок ${row.dueDate}',
                  amount: row.amount,
                  amountLabel: row.late ? 'просрочено' : 'ожидается',
                  late: row.late,
                  onTap: () => _collect(context, ref, row),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _collect(BuildContext context, WidgetRef ref, IncomePayRow row) async {
    final ym = ref.read(selectedFinanceYmProvider);
    final repo = ref.read(financeRepositoryProvider);
    await showFinancePaySheet(
      context: context,
      title: 'Получить оплату',
      subtitle: row.name,
      suggested: row.amount,
      submit: ({required accountId, required date, required amount, required comment}) async {
        if (row.hasPlan) {
          await repo.receivePlanned(
            plannedId: row.plannedId!,
            accountId: accountId,
            date: date,
            amount: amount,
          );
        } else {
          await repo.payNow(
            projectId: row.projectId,
            ym: ym,
            amount: amount,
            accountId: accountId,
            date: date,
            comment: comment.isEmpty ? null : comment,
          );
        }
      },
    );
  }
}

class FinanceExpensePage extends ConsumerWidget {
  const FinanceExpensePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeExpenseProvider);
    return _FinanceScaffold(
      title: 'Расход',
      subtitle: 'Зарплата, аренда, долги',
      onRefresh: () => ref.read(financeExpenseProvider.future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (data) => Column(
          children: [
            _PayCard(
              title: 'Зарплата',
              subtitle: '${data.salaryCount} сотрудников · к выплате',
              amount: data.salaryToPay,
              amountLabel: 'осталось',
              late: false,
              done: data.salaryCount > 0 && data.salaryToPay <= 0,
              onTap: () => context.push('/finance/salary'),
            ),
            _PayCard(
              title: 'Аренда и подписки',
              subtitle: '${data.subsCount} позиций',
              amount: data.subsToPay,
              amountLabel: 'осталось',
              late: false,
              done: data.subsCount > 0 && data.subsToPay <= 0,
              onTap: () => context.push('/finance/subscriptions'),
            ),
            _PayCard(
              title: 'Долги',
              subtitle: '${data.debtCount} открытых',
              amount: data.debtsMonthly,
              amountLabel: 'в месяц',
              late: false,
              onTap: () => context.push('/finance/debts'),
            ),
            _PayCard(
              title: 'Прочее',
              subtitle: 'Уже списано в этом месяце',
              amount: data.otherSpent,
              amountLabel: 'факт',
              late: false,
              onTap: () => context.push('/finance/transactions'),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceSalaryPage extends ConsumerWidget {
  const FinanceSalaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeSalaryProvider);
    return _FinanceScaffold(
      title: 'Зарплата',
      subtitle: 'Месяц начисления, не дата выплаты',
      onRefresh: () => ref.read(financeSalaryProvider.future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Ведомость пуста',
              message: 'В этом месяце нет сотрудников к выплате.',
              compact: true,
            );
          }
          return Column(
            children: [
              for (final row in rows)
                _PayCard(
                  title: row.name,
                  subtitle: row.frozen
                      ? 'Месяц закрыт'
                      : 'Оклад ${Money.somoni(row.salary)}'
                          '${row.bonus > 0 ? ' · бонус ${Money.somoni(row.bonus)}' : ''}'
                          '${row.advance > 0 ? ' · аванс ${Money.somoni(row.advance)}' : ''}',
                  amount: row.toPay,
                  amountLabel: row.frozen || row.toPay <= 0 ? 'выплачено' : 'к выплате',
                  done: row.frozen || row.toPay <= 0,
                  late: false,
                  onTap: row.frozen || row.toPay <= 0
                      ? null
                      : () => _pay(context, ref, row, 'Зарплата', row.toPay),
                  secondary: row.frozen
                      ? null
                      : () => _pay(context, ref, row, 'Аванс', row.toPay > 0 ? row.toPay : row.salary),
                  secondaryLabel: 'Аванс',
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    SalaryPayRow row,
    String marker,
    double suggested,
  ) async {
    final ym = ref.read(selectedFinanceYmProvider);
    await showFinancePaySheet(
      context: context,
      title: marker == 'Аванс' ? 'Выдать аванс' : 'Выплатить зарплату',
      subtitle: row.name,
      suggested: suggested,
      submit: ({required accountId, required date, required amount, required comment}) {
        return ref.read(financeRepositoryProvider).paySalary(
              employeeId: row.id,
              ym: ym,
              amount: amount,
              accountId: accountId,
              date: date,
              marker: marker,
              note: comment,
            );
      },
    );
  }
}

class FinanceSubscriptionsPage extends ConsumerWidget {
  const FinanceSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeSubscriptionsProvider);
    return _FinanceScaffold(
      title: 'Аренда и подписки',
      subtitle: 'Оплата со счёта или отметка без списания',
      onRefresh: () => ref.read(financeSubscriptionsProvider.future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (rows) {
          final live = rows.where((row) => row.active || row.paidMonth > 0).toList();
          if (live.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Позиций нет',
              message: 'В этом месяце нет аренды и подписок.',
              compact: true,
            );
          }
          return Column(
            children: [
              for (final row in live)
                _PayCard(
                  title: row.name,
                  subtitle: row.kind == 'rent' ? 'Аренда' : 'Подписка',
                  amount: row.remaining,
                  amountLabel: row.remaining <= 0 ? 'оплачено' : 'осталось',
                  done: row.remaining <= 0,
                  late: false,
                  onTap: row.remaining <= 0
                      ? null
                      : () => _pay(context, ref, row),
                  secondary: row.remaining <= 0
                      ? null
                      : () => _mark(context, ref, row),
                  secondaryLabel: 'Без списания',
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, SubscriptionPayRow row) async {
    await showFinancePaySheet(
      context: context,
      title: 'Оплатить',
      subtitle: row.name,
      suggested: row.remaining,
      maxAmount: row.remaining,
      submit: ({required accountId, required date, required amount, required comment}) {
        return ref.read(financeRepositoryProvider).paySubscription(
              row: row,
              amount: amount,
              accountId: accountId,
              date: date,
              note: comment,
            );
      },
    );
  }

  Future<void> _mark(BuildContext context, WidgetRef ref, SubscriptionPayRow row) async {
    final ym = ref.read(selectedFinanceYmProvider);
    await showConfirmSheet(
      context: context,
      title: 'Отметить без списания?',
      message: '${row.name} закроется за месяц, баланс счетов не изменится.',
      confirmLabel: 'Отметить',
      onConfirm: () async {
        await ref.read(financeRepositoryProvider).markSubscriptionPaid(row.id, ym);
        ref.read(dataRevisionProvider.notifier).bump();
      },
    );
  }
}

class FinanceDebtsPage extends ConsumerWidget {
  const FinanceDebtsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeDebtsProvider);
    return _FinanceScaffold(
      title: 'Долги',
      subtitle: 'Платёж за выбранный месяц',
      onRefresh: () => ref.read(financeDebtsProvider.future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (rows) {
          final open = rows.where((row) => row.remaining > 0 || row.dueMonth > 0).toList();
          if (open.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Долгов нет',
              message: 'Открытых долгов к оплате не осталось.',
              compact: true,
            );
          }
          return Column(
            children: [
              for (final row in open)
                _PayCard(
                  title: row.name,
                  subtitle: 'Остаток ${Money.somoni(row.remaining)}',
                  amount: row.dueMonth > 0 ? row.dueMonth : row.remaining,
                  amountLabel: row.dueMonth > 0 ? 'в этом месяце' : 'остаток',
                  late: false,
                  done: row.remaining <= 0,
                  onTap: row.remaining <= 0
                      ? null
                      : () => _pay(context, ref, row),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, DebtPayRow row) async {
    final ym = ref.read(selectedFinanceYmProvider);
    final amount = row.dueMonth > 0 ? row.dueMonth : row.remaining;
    await showFinancePaySheet(
      context: context,
      title: 'Оплатить долг',
      subtitle: row.name,
      suggested: amount,
      maxAmount: row.remaining > 0 ? row.remaining : null,
      submit: ({required accountId, required date, required amount, required comment}) {
        return ref.read(financeRepositoryProvider).payNow(
              debtId: row.id,
              ym: ym,
              amount: amount,
              accountId: accountId,
              date: date,
              comment: comment.isEmpty ? null : comment,
            );
      },
    );
  }
}

class FinanceJournalPage extends ConsumerWidget {
  const FinanceJournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeJournalProvider);
    return _FinanceScaffold(
      title: 'Журнал',
      subtitle: 'Операции выбранного месяца',
      onRefresh: () => ref.read(financeJournalProvider.future),
      body: async.when(
        loading: () => const _FinanceLoader(),
        error: (error, _) => _FinanceError(
          message: _message(error),
          onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_outlined,
              title: 'Операций нет',
              message: 'В этом месяце журнал пуст.',
              compact: true,
            );
          }
          return Column(
            children: [
              for (final row in rows)
                _PayCard(
                  title: row.description ?? _typeLabel(row.type),
                  subtitle: '${_typeLabel(row.type)}'
                      '${row.date == null ? '' : ' · ${BizDate.dateShort(row.date!)}'}'
                      '${row.accountName == null ? '' : ' · ${row.accountName}'}',
                  amount: row.amount,
                  amountLabel: _typeLabel(row.type),
                  late: false,
                  onTap: row.id.isEmpty
                      ? null
                      : () => showConfirmSheet(
                            context: context,
                            title: 'Удалить операцию?',
                            message: 'Сумма вернётся на баланс счёта. Это нельзя отменить из приложения.',
                            confirmLabel: 'Удалить',
                            danger: true,
                            onConfirm: () async {
                              await ref.read(financeRepositoryProvider).deleteTransaction(row.id);
                              ref.read(dataRevisionProvider.notifier).bump();
                            },
                          ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'income' => 'Доход',
        'expense' => 'Расход',
        'transfer' => 'Перевод',
        'saving' => 'Накопление',
        _ => type,
      };
}

class _FinanceScaffold extends ConsumerWidget {
  const _FinanceScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ym = ref.watch(selectedFinanceYmProvider);
    return AppPage(
      header: AppHeader(
        title: title,
        subtitle: subtitle,
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await onRefresh();
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinanceMonthBar(ym: ym),
              const SizedBox(height: 14),
              body,
            ],
          ),
        ),
      ],
    );
  }
}

class FinanceMonthBar extends ConsumerWidget {
  const FinanceMonthBar({super.key, required this.ym});

  final String ym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DateTime parsed;
    try {
      parsed = DateFormat('yyyy-MM').parse(ym);
    } catch (_) {
      parsed = DateTime.now();
    }
    final label = DateFormat('LLLL yyyy', 'ru').format(parsed);
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
            onPressed: () => ref.read(selectedFinanceYmProvider.notifier).setYm(
                  DateFormat('yyyy-MM').format(DateTime(parsed.year, parsed.month - 1)),
                ),
          ),
          Text(
            label.toUpperCase(),
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
            onPressed: () => ref.read(selectedFinanceYmProvider.notifier).setYm(
                  DateFormat('yyyy-MM').format(DateTime(parsed.year, parsed.month + 1)),
                ),
          ),
        ],
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountLabel,
    required this.late,
    this.done = false,
    this.onTap,
    this.secondary,
    this.secondaryLabel,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String amountLabel;
  final bool late;
  final bool done;
  final VoidCallback? onTap;
  final VoidCallback? secondary;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final amountColor = done
        ? AppColors.success
        : late
            ? AppColors.danger
            : AppColors.text;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      radius: 16,
      onTap: onTap,
      borderColor: late ? AppColors.danger.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.somoni(amount),
                    maxLines: 1,
                    style: AppTypography.number(
                      size: 15,
                      weight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amountLabel,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (secondary != null) ...[
            const SizedBox(height: 10),
            AppButton(
              label: secondaryLabel ?? 'Ещё',
              variant: AppButtonVariant.ghost,
              compact: true,
              expanded: false,
              onPressed: secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _FinanceLoader extends StatelessWidget {
  const _FinanceLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
    );
  }
}

class _FinanceError extends StatelessWidget {
  const _FinanceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Не удалось загрузить',
      message: message,
      actionLabel: 'Повторить',
      onAction: onRetry,
      compact: true,
    );
  }
}

String _message(Object error) {
  if (error is ApiException) return error.message;
  return 'Проверьте соединение и повторите.';
}

Future<void> showFinancePaySheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required double suggested,
  double? maxAmount,
  required Future<void> Function({
    required String accountId,
    required String date,
    required double amount,
    required String comment,
  }) submit,
}) {
  return showGlassSheet<void>(
    context: context,
    title: title,
    subtitle: subtitle,
    child: _FinancePayForm(
      suggested: suggested,
      maxAmount: maxAmount,
      submit: submit,
    ),
  );
}

class _FinancePayForm extends ConsumerStatefulWidget {
  const _FinancePayForm({
    required this.suggested,
    required this.submit,
    this.maxAmount,
  });

  final double suggested;
  final double? maxAmount;
  final Future<void> Function({
    required String accountId,
    required String date,
    required double amount,
    required String comment,
  }) submit;

  @override
  ConsumerState<_FinancePayForm> createState() => _FinancePayFormState();
}

class _FinancePayFormState extends ConsumerState<_FinancePayForm> {
  late final TextEditingController _amount;
  final _comment = TextEditingController();
  List<FinanceAccount> _accounts = const [];
  String? _accountId;
  final DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.suggested > 0 ? widget.suggested.toStringAsFixed(2) : '',
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await ref.read(financeRepositoryProvider).accounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _accountId = accounts.isEmpty ? null : accounts.first.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : 'Не удалось загрузить счета';
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Сумма должна быть больше нуля');
      return;
    }
    if (widget.maxAmount != null && amount > widget.maxAmount! + 0.005) {
      setState(() => _error = 'Сумма больше остатка ${Money.somoni(widget.maxAmount)}');
      return;
    }
    if (_accountId == null || _accountId!.isEmpty) {
      setState(() => _error = 'Выберите счёт');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit(
        accountId: _accountId!,
        date: DateFormat('yyyy-MM-dd').format(_date),
        amount: amount,
        comment: _comment.text.trim(),
      );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.read(dependenciesProvider).banners.show(const AppBanner(
            title: 'Оплата проведена',
            message: 'Журнал и балансы обновлены.',
            tone: BannerTone.success,
          ));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось провести оплату');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Сумма, сомони'),
        ),
        const SizedBox(height: 12),
        if (_accounts.isEmpty)
          const Text(
            'Счета не настроены. Добавьте их в веб-версии финансов.',
            style: TextStyle(
              fontFamily: AppTypography.family,
              color: AppColors.danger,
              fontSize: 12.5,
              height: 1.35,
            ),
          )
        else
          FinanceAccountPicker(
            accounts: _accounts,
            selectedId: _accountId,
            onSelected: (id) => setState(() => _accountId = id),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _comment,
          decoration: const InputDecoration(labelText: 'Комментарий'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              color: AppColors.danger,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: _saving ? 'Провожу…' : 'Провести',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving || _accounts.isEmpty ? null : _save,
        ),
      ],
    );
  }
}

class FinanceAccountPicker extends StatelessWidget {
  const FinanceAccountPicker({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
    this.labelOf,
  });

  final List<FinanceAccount> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String Function(FinanceAccount account)? labelOf;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final account in accounts)
              _AccountSelectChip(
                label: labelOf?.call(account) ?? account.name,
                selected: selectedId == account.id,
                maxWidth: maxWidth,
                onTap: () => onSelected(account.id),
              ),
          ],
        );
      },
    );
  }
}

class _AccountSelectChip extends StatelessWidget {
  const _AccountSelectChip({
    required this.label,
    required this.selected,
    required this.maxWidth,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentBright : AppColors.textSecondary;
    return PressableScale(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 44, maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.13) : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent.withValues(alpha: 0.32) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
