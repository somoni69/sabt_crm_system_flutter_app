import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/client_lead.dart';
import 'clients_providers.dart';

Future<String?> showClientForm(
  BuildContext context,
  WidgetRef ref, {
  ClientLeadModel? client,
}) async {
  final user = ref.read(currentUserProvider);
  final allowed = client == null
      ? userCan(user, Perm.clientsCreate)
      : userCan(user, Perm.clientsEdit);
  if (!allowed) {
    ref.read(dependenciesProvider).banners.show(const AppBanner(
          title: 'Недостаточно прав',
          message: 'Ваша роль не позволяет изменять базу клиентов.',
          tone: BannerTone.warning,
        ));
    return null;
  }

  return showGlassSheet<String>(
    context: context,
    title: client == null ? 'Новый лид' : 'Редактировать клиента',
    subtitle: client == null
        ? 'Добавьте контакт в базу и назначьте следующий шаг.'
        : 'Обновите статус, контакты и договорённости.',
    maxHeightFactor: 0.92,
    child: _ClientForm(client: client),
  );
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({this.client});

  final ClientLeadModel? client;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  late final _name = TextEditingController(text: widget.client?.name ?? '');
  late final _sphere = TextEditingController(text: widget.client?.sphere ?? '');
  late final _person = TextEditingController(text: widget.client?.contactPerson ?? '');
  late final _phone = TextEditingController(text: widget.client?.contactPhone ?? '');
  late final _instagram =
      TextEditingController(text: widget.client?.contactInstagram ?? '');
  late final _email = TextEditingController(text: widget.client?.contactEmail ?? '');
  late final _problem = TextEditingController(text: widget.client?.problem ?? '');
  late final _nextStep = TextEditingController(text: widget.client?.nextStep ?? '');
  late final _source = TextEditingController(text: widget.client?.leadSource ?? '');
  late final _potential = TextEditingController(
    text: widget.client?.dealPotential == null
        ? ''
        : '${widget.client!.dealPotential!.round()}',
  );

  late String _status = widget.client?.status ?? 'new';
  late String _interest = widget.client?.interest ?? 'warm';
  DateTime? _nextContact;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nextContact = widget.client?.nextContactAt;
  }

  @override
  void dispose() {
    _name.dispose();
    _sphere.dispose();
    _person.dispose();
    _phone.dispose();
    _instagram.dispose();
    _email.dispose();
    _problem.dispose();
    _nextStep.dispose();
    _source.dispose();
    _potential.dispose();
    super.dispose();
  }

  Future<void> _pickNextContact() async {
    final now = BizDate.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _nextContact ?? now,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Следующий контакт',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (value == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextContact ?? now),
      helpText: 'Время контакта',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (!mounted) return;
    setState(() {
      _nextContact = DateTime(
        value.year,
        value.month,
        value.day,
        time?.hour ?? 10,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название клиента');
      return;
    }
    final potential = double.tryParse(_potential.text.replaceAll(',', '.'));
    setState(() {
      _busy = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'name': name,
      'sphere': _sphere.text.trim(),
      'contactPerson': _person.text.trim(),
      'contactPhone': _phone.text.trim(),
      'contactInstagram': _instagram.text.trim(),
      'contactEmail': _email.text.trim(),
      'problem': _problem.text.trim(),
      'nextStep': _nextStep.text.trim(),
      'leadSource': _source.text.trim(),
      'status': _status,
      'interest': _interest,
      'dealPotential': ?potential,
      if (_nextContact != null) 'nextContactAt': BizDate.toApiIso(_nextContact!),
    };

    final deps = ref.read(dependenciesProvider);
    try {
      if (widget.client == null) {
        final created = await ref.read(clientsRepositoryProvider).create(body);
        ref.read(dataRevisionProvider.notifier).bump();
        deps.banners.show(const AppBanner(
          title: 'Лид добавлен',
          message: 'Контакт появился в базе клиентов.',
          tone: BannerTone.success,
        ));
        if (mounted) Navigator.of(context).pop('${created['id'] ?? ''}');
      } else {
        await ref
            .read(clientsRepositoryProvider)
            .update(widget.client!.id, body);
        ref.read(dataRevisionProvider.notifier).bump();
        deps.banners.show(const AppBanner(
          title: 'Клиент обновлён',
          message: 'Изменения сохранены.',
          tone: BannerTone.success,
        ));
        if (mounted) Navigator.of(context).pop(widget.client!.id);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить клиента');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _name,
          enabled: !_busy,
          autofocus: widget.client == null,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Название компании или бренда',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _sphere,
          enabled: !_busy,
          textCapitalization: TextCapitalization.sentences,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Сфера: ресторан, клиника, блогер…',
            prefixIcon: Icon(Icons.category_outlined, size: 19),
          ),
        ),
        const FormSectionLabel('Контакт'),
        TextField(
          controller: _person,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Имя ЛПР',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: '+992 __ ___ ____',
            prefixIcon: Icon(Icons.call_outlined, size: 19),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _instagram,
                enabled: !_busy,
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  color: context.palette.text,
                ),
                decoration: const InputDecoration(
                  hintText: '@instagram',
                  prefixIcon: Icon(Icons.camera_alt_outlined, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  color: context.palette.text,
                ),
                decoration: const InputDecoration(
                  hintText: 'email',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const FormSectionLabel('Статус'),
        AppSelectField<String>(
          value: _status,
          items: const [
            'new',
            'waiting',
            'negotiating',
            'proposal',
            'won',
            'lost',
            'on_hold',
          ],
          labelOf: (value) => switch (value) {
            'new' => 'Новый',
            'waiting' => 'Ожидание ответа',
            'negotiating' => 'В переговорах',
            'proposal' => 'Предложение отправлено',
            'won' => 'Сделка закрыта',
            'lost' => 'Отказ',
            'on_hold' => 'На паузе',
            _ => value,
          },
          onChanged: (value) {
            if (value != null) setState(() => _status = value);
          },
        ),
        const FormSectionLabel('Интерес'),
        AppChoiceChips<String>(
          selected: _interest,
          onChanged: (value) => setState(() => _interest = value),
          options:  [
            AppChoice(
              value: 'cold',
              label: 'Холодный',
              color: context.palette.info,
            ),
            AppChoice(
              value: 'warm',
              label: 'Тёплый',
              color: context.palette.warning,
            ),
            AppChoice(
              value: 'hot',
              label: 'Горячий',
              color: context.palette.danger,
            ),
          ],
        ),
        const FormSectionLabel('Потенциал сделки'),
        TextField(
          controller: _potential,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Например, 12000',
            suffixText: 'сомони',
            prefixIcon: Icon(Icons.payments_outlined, size: 19),
          ),
        ),
        const FormSectionLabel('Следующий контакт'),
        AppFieldRow(
          label: 'Дата и время',
          onTrailingTap: _busy ? null : _pickNextContact,
          trailing:  Icon(Icons.edit_calendar_outlined,
              size: 18, color: context.palette.accentBright),
          child: GestureDetector(
            onTap: _busy ? null : _pickNextContact,
            child: Text(
              _nextContact == null
                  ? 'Не назначен'
                  : '${BizDate.fullDate(_nextContact!)} · ${BizDate.time(_nextContact!)}',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _nextContact == null
                    ? context.palette.textTertiary
                    : context.palette.text,
              ),
            ),
          ),
        ),
        const FormSectionLabel('Задача / следующий шаг'),
        TextField(
          controller: _nextStep,
          enabled: !_busy,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13.5,
            height: 1.45,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(hintText: 'Что нужно сделать дальше?'),
        ),
        const FormSectionLabel('Проблема клиента'),
        TextField(
          controller: _problem,
          enabled: !_busy,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13.5,
            height: 1.45,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(hintText: 'Какую задачу решаем?'),
        ),
        const FormSectionLabel('Источник'),
        TextField(
          controller: _source,
          enabled: !_busy,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13.5,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Instagram, рекомендация, обзвон…',
            prefixIcon: Icon(Icons.hub_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: widget.client == null ? 'Добавить в базу' : 'Сохранить',
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
