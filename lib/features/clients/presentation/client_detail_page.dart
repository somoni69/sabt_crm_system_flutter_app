import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/client_lead.dart';
import 'client_form_sheet.dart';
import 'clients_providers.dart';

class ClientDetailPage extends ConsumerStatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage> {
  bool _busy = false;

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _open(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) _error('Не удалось открыть ссылку');
    } catch (_) {
      _error('Не удалось открыть ссылку');
    }
  }

  void _error(String message) {
    ref.read(dependenciesProvider).banners.show(AppBanner(
          title: 'Ошибка',
          message: message,
          tone: BannerTone.danger,
        ));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: success,
            message: '',
            tone: BannerTone.success,
            icon: Icons.check_circle_outline_rounded,
          ));
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } catch (_) {
      if (mounted) _error('Не удалось выполнить действие');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markCalled(ClientLeadModel client) async {
    await _run(() async {
      await ref.read(clientsRepositoryProvider).update(client.id, {
        'lastContactAt': BizDate.toApiIso(BizDate.now()),
      });
      if (client.callRequested) {
        await ref.read(clientsRepositoryProvider).setCallRequest(client.id, false);
      }
    }, 'Звонок отмечен');
  }

  Future<void> _toggleCallRequest(ClientLeadModel client) async {
    await _run(
      () => ref
          .read(clientsRepositoryProvider)
          .setCallRequest(client.id, !client.callRequested),
      client.callRequested ? 'Запрос снят' : 'Запрос на звонок отправлен',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (!canSeeClients(user)) {
      return AppPage(
        showBottomBarSpace: false,
        header: AppHeader(title: 'Клиент', onBack: () => context.pop()),
        slivers: const [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Клиент недоступен',
            message: 'У вашей роли нет доступа к базе клиентов.',
          ),
        ],
      );
    }

    final canEdit = userCan(user, Perm.clientsEdit);
    final canDelete = userCan(user, Perm.clientsDelete);
    final async = ref.watch(clientProvider(widget.clientId));
    final snapshot = async.value;
    final client = snapshot?.data;

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: 'Клиент',
        subtitle: client?.name,
        onBack: () => context.pop(),
        actions: [
          if (client?.contactPhone != null && client!.contactPhone!.isNotEmpty)
            AppIconButton(
              icon: Icons.call_outlined,
              size: 40,
              onPressed: () => _open('tel:${client.contactPhone}'),
              tooltip: 'Позвонить',
            ),
          if (client != null && canEdit)
            AppIconButton(
              icon: Icons.edit_outlined,
              size: 40,
              onPressed: () => showClientForm(context, ref, client: client),
              tooltip: 'Редактировать',
            ),
        ],
      ),
      onRefresh: _refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: client == null
              ? _placeholder(async, _refresh)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot?.error != null) ...[
                      OfflineRibbon(
                        cachedAt: snapshot?.savedAt,
                        showRetry: true,
                        onRetry: _refresh,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _ClientHero(
                      client: client,
                      canEdit: canEdit,
                      busy: _busy,
                      onClearRequest: () => _toggleCallRequest(client),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (client.contactPhone != null)
                          Expanded(
                            child: _ContactAction(
                              icon: Icons.call_rounded,
                              label: 'Позвонить',
                              color: AppColors.success,
                              onTap: () => _open('tel:${client.contactPhone}'),
                            ),
                          ),
                        if (client.contactPhone != null) const SizedBox(width: 8),
                        if (client.contactEmail != null)
                          Expanded(
                            child: _ContactAction(
                              icon: Icons.mail_outline_rounded,
                              label: 'Письмо',
                              color: AppColors.info,
                              onTap: () => _open('mailto:${client.contactEmail}'),
                            ),
                          ),
                        if (client.contactEmail != null) const SizedBox(width: 8),
                        if (client.contactInstagram != null)
                          Expanded(
                            child: _ContactAction(
                              icon: Icons.camera_alt_outlined,
                              label: 'Instagram',
                              color: AppColors.accentBright,
                              onTap: () => _open(
                                client.contactInstagram!.startsWith('http')
                                    ? client.contactInstagram
                                    : 'https://instagram.com/${client.contactInstagram!.replaceAll('@', '')}',
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: 10),
                      AppButton(
                        label: client.callRequested
                            ? 'Звонок сделан'
                            : 'Отметить звонок',
                        icon: Icons.phone_callback_rounded,
                        variant: AppButtonVariant.secondary,
                        compact: true,
                        loading: _busy,
                        onPressed: _busy ? null : () => _markCalled(client),
                      ),
                    ],
                    if (client.nextStep != null ||
                        client.nextContactAt != null ||
                        client.repeatCallAt != null) ...[
                      const SizedBox(height: 20),
                      const SectionHeader(
                        overline: 'СЛЕДУЮЩИЙ ШАГ',
                        title: 'Договорённости',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        radius: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (client.nextStep != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  client.nextStep!,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.family,
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.borderSoft),
                            ],
                            if (client.nextContactAt != null)
                              KeyValueRow(
                                label: 'Следующий контакт',
                                value: BizDate.deadline(client.nextContactAt),
                                icon: Icons.event_available_outlined,
                                valueColor: client.nextContactOverdue
                                    ? AppColors.danger
                                    : null,
                              ),
                            if (client.repeatCallAt != null) ...[
                              const Divider(height: 1, color: AppColors.borderSoft),
                              KeyValueRow(
                                label: 'Повторный звонок',
                                value: BizDate.deadline(client.repeatCallAt),
                                icon: Icons.phone_callback_rounded,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (client.problem != null) ...[
                      const SizedBox(height: 20),
                      const SectionHeader(overline: 'ЗАДАЧА', title: 'Проблема клиента'),
                      AppCard(
                        padding: const EdgeInsets.all(15),
                        radius: 18,
                        child: Text(
                          client.problem!,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 13,
                            height: 1.55,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const SectionHeader(overline: 'КАРТОЧКА', title: 'Детали'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      radius: 20,
                      child: Column(
                        children: [
                          KeyValueRow(
                            label: 'Направление',
                            value: client.directionLabel,
                            icon: Icons.alt_route_rounded,
                          ),
                          if (client.ownerName != null) ...[
                            const Divider(height: 1, color: AppColors.borderSoft),
                            KeyValueRow(
                              label: 'Менеджер',
                              value: client.ownerName!,
                              icon: Icons.support_agent_rounded,
                            ),
                          ],
                          if (client.leadSource != null) ...[
                            const Divider(height: 1, color: AppColors.borderSoft),
                            KeyValueRow(
                              label: 'Источник',
                              value: client.leadSource!,
                              icon: Icons.hub_outlined,
                            ),
                          ],
                          if (client.channel != null) ...[
                            const Divider(height: 1, color: AppColors.borderSoft),
                            KeyValueRow(
                              label: 'Канал',
                              value: client.channel!,
                              icon: Icons.forum_outlined,
                            ),
                          ],
                          if (client.lastContactAt != null) ...[
                            const Divider(height: 1, color: AppColors.borderSoft),
                            KeyValueRow(
                              label: 'Последний контакт',
                              value: BizDate.dateWithYear(client.lastContactAt!),
                              icon: Icons.history_rounded,
                            ),
                          ],
                          if (client.lastActivityAt != null) ...[
                            const Divider(height: 1, color: AppColors.borderSoft),
                            KeyValueRow(
                              label: 'Активность',
                              value: BizDate.relative(client.lastActivityAt!),
                              icon: Icons.bolt_outlined,
                            ),
                          ],
                          if (client.address != null) ...[
                            const Divider(height: 1, color: AppColors.borderSoft),
                            KeyValueRow(
                              label: 'Адрес',
                              value: client.address!,
                              icon: Icons.place_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (client.rejectionReason != null) ...[
                      const SizedBox(height: 20),
                      const SectionHeader(overline: 'ОТКАЗ', title: 'Причина'),
                      AppCard(
                        padding: const EdgeInsets.all(15),
                        radius: 18,
                        child: Text(
                          client.rejectionReason!,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                    if (canDelete) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Удалить клиента',
                        icon: Icons.delete_outline_rounded,
                        variant: AppButtonVariant.danger,
                        compact: true,
                        onPressed: _busy
                            ? null
                            : () => showConfirmSheet(
                                  context: context,
                                  title: 'Удалить клиента?',
                                  message: client.name,
                                  confirmLabel: 'Удалить',
                                  danger: true,
                                  onConfirm: () async {
                                    await ref.read(clientsRepositoryProvider).remove(client.id);
                                    ref.read(dataRevisionProvider.notifier).bump();
                                    if (context.mounted) context.pop();
                                  },
                                ),
                      ),
                    ],
                    if (canEdit) ...[
                      const SizedBox(height: 18),
                      AppButton(
                        label: client.callRequested
                            ? 'Снять запрос на звонок'
                            : 'Запросить звонок у руководителя',
                        icon: Icons.notification_add_outlined,
                        variant: AppButtonVariant.ghost,
                        compact: true,
                        onPressed: _busy ? null : () => _toggleCallRequest(client),
                      ),
                    ],
                    const SizedBox(height: 26),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _placeholder(AsyncValue<dynamic> async, Future<void> Function() retry) {
    if (async.hasError) {
      final error = async.error;
      return InlineError(
        message: error is ApiException ? error.message : 'Клиент не найден',
        onRetry: retry,
      );
    }
    return const Column(
      children: [
        SkeletonBox(height: 190, radius: 24),
        SizedBox(height: 14),
        SkeletonBox(height: 60, radius: 16),
        SizedBox(height: 14),
        SkeletonBox(height: 220, radius: 20),
      ],
    );
  }
}

class _ClientHero extends StatelessWidget {
  const _ClientHero({
    required this.client,
    required this.canEdit,
    required this.busy,
    required this.onClearRequest,
  });

  final ClientLeadModel client;
  final bool canEdit;
  final bool busy;
  final VoidCallback onClearRequest;

  ChipTone get _statusTone => switch (client.status) {
        'won' => ChipTone.success,
        'lost' => ChipTone.danger,
        'on_hold' => ChipTone.warning,
        'negotiating' || 'proposal' => ChipTone.warning,
        'waiting' => ChipTone.info,
        _ => ChipTone.neutral,
      };

  ChipTone get _interestTone => switch (client.interest) {
        'hot' => ChipTone.danger,
        'warm' => ChipTone.warning,
        'cold' => ChipTone.info,
        _ => ChipTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2032), Color(0xFF111624), Color(0xFF171229)],
        ),
        border: Border.all(
          color: client.callRequested
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SurfaceIcon(
                icon: client.isDev ? Icons.code_rounded : Icons.auto_awesome_rounded,
                color: client.isDev ? AppColors.ice : AppColors.accent,
                size: 48,
                radius: 15,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(
                          label: client.statusLabel,
                          tone: _statusTone,
                          compact: true,
                          dot: true,
                        ),
                        AppChip(
                          label: client.interestLabel,
                          tone: _interestTone,
                          compact: true,
                        ),
                        AppChip(
                          label: client.directionLabel,
                          tone: ChipTone.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 23,
                        height: 1.18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: AppColors.text,
                      ),
                    ),
                    if (client.sphere != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        client.sphere!,
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (client.callRequested) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.callRequestedByName == null
                          ? 'Руководитель просит позвонить клиенту'
                          : '${client.callRequestedByName} просит позвонить клиенту',
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        height: 1.35,
                        color: Color(0xFFFFD79A),
                      ),
                    ),
                  ),
                  if (canEdit)
                    TextButton(
                      onPressed: busy ? null : onClearRequest,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Снять'),
                    ),
                ],
              ),
            ),
          ],
          if (client.dealPotential != null && client.dealPotential! > 0) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.somoni(client.dealPotential),
                  style: AppTypography.number(size: 27, color: AppColors.text),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'потенциал сделки',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 11),
      radius: 16,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
