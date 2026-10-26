import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/dependencies.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_banner.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/app_form.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, required this.accounts});

  final List<FinanceAccount> accounts;

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'income'; // income, expense
  String? _accountId;
  final DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ref.read(dependenciesProvider).banners.show(const AppBanner(
        title: 'Укажите сумму',
        message: 'Сумма операции должна быть больше нуля.',
        tone: BannerTone.danger,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).createOperation({
        'type': _type,
        'amount': amount,
        'description': _descController.text.trim(),
        'accountId': _accountId,
        'date': DateFormat('yyyy-MM-dd').format(_date),
      });

      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) {
        Navigator.of(context).pop(true);
        ref.read(dependenciesProvider).banners.show(const AppBanner(
          title: 'Операция сохранена',
          message: 'Транзакция успешно добавлена в журнал.',
          tone: BannerTone.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ref.read(dependenciesProvider).banners.show(AppBanner(
          title: 'Ошибка',
          message: e.toString(),
          tone: BannerTone.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppChoiceChips<String>(
          selected: _type,
          onChanged: (val) => setState(() => _type = val),
          options: const [
            AppChoice(value: 'income', label: 'Доход', color: AppColors.success),
            AppChoice(value: 'expense', label: 'Расход', color: AppColors.danger),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Сумма (с.)',
            hintText: '0.00',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: 'Описание / Назначение',
            hintText: 'Например, Оплата за ведение SMM',
          ),
        ),
        if (widget.accounts.isNotEmpty) ...[
          const SizedBox(height: 14),
          const FormSectionLabel('Счёт списания / зачисления'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.accounts.map((acc) {
              final selected = _accountId == acc.id;
              return ChoiceChip(
                label: Text('${acc.name} (${acc.balance.toStringAsFixed(0)} с.)'),
                selected: selected,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surface2,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _accountId = acc.id),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: _saving ? 'Сохранение...' : 'Добавить операцию',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
