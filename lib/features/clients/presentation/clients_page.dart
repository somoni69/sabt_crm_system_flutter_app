import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/client_lead.dart';
import 'client_form_sheet.dart';
import 'clients_providers.dart';

enum _ClientFilter { all, active, fresh, inProgress, won, lost }

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _search = TextEditingController();
  _ClientFilter _filter = _ClientFilter.all;
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ClientLeadModel client) {
    switch (_filter) {
      case _ClientFilter.all:
        break;
      case _ClientFilter.active:
        if (!client.isActive) return false;
        break;
      case _ClientFilter.fresh:
        if (client.status != 'new') return false;
        break;
      case _ClientFilter.inProgress:
        if (!const ['waiting', 'negotiating', 'proposal'].contains(client.status)) {
          return false;
        }
        break;
      case _ClientFilter.won:
        if (!client.isWon) return false;
        break;
      case _ClientFilter.lost:
        if (client.status != 'lost' && client.status != 'on_hold') return false;
        break;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return client.name.toLowerCase().contains(query) ||
        (client.sphere ?? '').toLowerCase().contains(query) ||
        (client.contactPerson ?? '').toLowerCase().contains(query) ||
        (client.contactPhone ?? '').contains(query) ||
        (client.contactInstagram ?? '').toLowerCase().contains(query) ||
        (client.ownerName ?? '').toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canSee = canSeeClients(user);
    final canCreate = userCan(user, Perm.clientsCreate);
    final async = ref.watch(clientsProvider);
    final snapshot = async.value;
    final all = snapshot?.data ?? const <ClientLeadModel>[];
    final clients = all.where(_matches).toList();

    int count(bool Function(ClientLeadModel) test) => all.where(test).length;
    final activeCount = count((client) => client.isActive);
    final freshCount = count((client) => client.status == 'new');
    final progressCount = count(
      (client) => const ['waiting', 'negotiating', 'proposal'].contains(client.status),
    );
    final wonCount = count((client) => client.isWon);
    final lostCount = count(
      (client) => client.status == 'lost' || client.status == 'on_hold',
    );

    final error = async.error;
    final errorMessage =
        error is ApiException ? error.message : 'Не удалось загрузить клиентов';

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return AppPage(
      showBottomBarSpace: widget.embedded,
      header: AppHeader(
        title: 'Клиенты',
        subtitle: all.isEmpty
            ? 'База лидов и клиентов'
            : '${all.length} в базе · ${all.where((client) => client.callRequested).length} позвонить',
        onBack: widget.embedded ? null : () => context.pop(),
        actions: [
          AppIconButton(
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            size: 40,
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _search.clear();
                  _query = '';
                }
              });
            },
          ),
          if (canCreate)
            AppIconButton(
              icon: Icons.person_add_alt_1_rounded,
              size: 40,
              filled: true,
              color: Colors.white,
              onPressed: () async {
                final id = await showClientForm(context, ref);
                if (id != null && id.isNotEmpty && context.mounted) {
                  context.push('/clients/$id');
                }
              },
            ),
        ],
      ),
      onRefresh: canSee ? refresh : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded)
                const PageIntro(
                  overline: 'ПРОДАЖИ',
                  title: 'База клиентов',
                  subtitle: 'Лиды, переговоры и действующие клиенты агентства.',
                ),
              if (!canSee)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Раздел недоступен',
                  message: 'У вашей роли нет доступа к базе клиентов.',
                )
              else ...[
                if (_searchOpen) ...[
                  AppSearchField(
                    controller: _search,
                    hint: 'Имя, контакт, сфера или менеджер',
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Все',
                        count: all.length,
                        active: _filter == _ClientFilter.all,
                        onTap: () => setState(() => _filter = _ClientFilter.all),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Активные',
                        count: activeCount,
                        active: _filter == _ClientFilter.active,
                        onTap: () => setState(() => _filter = _ClientFilter.active),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Новые',
                        count: freshCount,
                        active: _filter == _ClientFilter.fresh,
                        tone: ChipTone.info,
                        onTap: () => setState(() => _filter = _ClientFilter.fresh),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'В работе',
                        count: progressCount,
                        active: _filter == _ClientFilter.inProgress,
                        tone: ChipTone.warning,
                        onTap: () => setState(() => _filter = _ClientFilter.inProgress),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Клиенты',
                        count: wonCount,
                        active: _filter == _ClientFilter.won,
                        tone: ChipTone.success,
                        onTap: () => setState(() => _filter = _ClientFilter.won),
                      ),
                      const SizedBox(width: 7),
                      _FilterChip(
                        label: 'Отказ',
                        count: lostCount,
                        active: _filter == _ClientFilter.lost,
                        tone: ChipTone.danger,
                        onTap: () => setState(() => _filter = _ClientFilter.lost),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot?.error != null && all.isEmpty)
                  InlineError(message: errorMessage, onRetry: refresh)
                else if (async.isLoading && snapshot == null)
                  const _ClientsSkeleton()
                else if (error != null && snapshot == null)
                  InlineError(message: errorMessage, onRetry: refresh)
                else if (clients.isEmpty)
                  EmptyState(
                    icon: Icons.person_search_outlined,
                    title: _query.isEmpty ? 'Здесь пока пусто' : 'Клиенты не найдены',
                    message: _query.isEmpty
                        ? 'Добавьте первый лид — он появится в базе и в KPI менеджеров.'
                        : 'Измените запрос или фильтр.',
                    actionLabel: canCreate && _query.isEmpty ? 'Добавить лид' : null,
                    onAction: canCreate
                        ? () => showClientForm(context, ref)
                        : null,
                    compact: true,
                  )
                else ...[
                  if (snapshot?.error != null) ...[
                    OfflineRibbon(
                      cachedAt: snapshot?.savedAt,
                      showRetry: true,
                      onRetry: refresh,
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final client in clients) ...[
                    _ClientCard(client: client),
                    const SizedBox(height: 9),
                  ],
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.tone = ChipTone.accent,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: '$label · $count',
      tone: active ? tone : ChipTone.neutral,
      onTap: onTap,
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});

  final ClientLeadModel client;

  ChipTone get _statusTone => switch (client.status) {
        'won' => ChipTone.success,
        'lost' => ChipTone.danger,
        'on_hold' => ChipTone.warning,
        'negotiating' || 'proposal' => ChipTone.warning,
        'waiting' => ChipTone.info,
        _ => ChipTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final directionColor = client.isDev ? context.palette.ice : context.palette.accent;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      radius: 18,
      onTap: () => context.push('/clients/${client.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SurfaceIcon(
            icon: client.isDev ? Icons.code_rounded : Icons.auto_awesome_rounded,
            color: directionColor,
            size: 42,
            radius: 13,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: context.palette.text,
                        ),
                      ),
                    ),
                    if (client.isHot) ...[
                      const SizedBox(width: 5),
                       Icon(Icons.local_fire_department_rounded,
                          size: 15, color: context.palette.danger),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (client.sphere != null) client.sphere!,
                    if (client.contactPerson != null) client.contactPerson!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    color: context.palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChip(
                      label: client.statusLabel,
                      tone: _statusTone,
                      compact: true,
                      dot: true,
                    ),
                    if (client.callRequested)
                      const AppChip(
                        label: 'Позвонить',
                        tone: ChipTone.danger,
                        icon: Icons.call_outlined,
                        compact: true,
                      ),
                    if (client.nextContactAt != null)
                      Text(
                        client.nextContactOverdue
                            ? 'Связь просрочена'
                            : 'Контакт ${BizDate.deadline(client.nextContactAt)}',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: client.nextContactOverdue
                              ? context.palette.danger
                              : client.nextContactToday
                                  ? context.palette.warning
                                  : context.palette.textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (client.dealPotential != null && client.dealPotential! > 0)
                Text(
                  Money.somoni(client.dealPotential, compact: true),
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textSecondary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              const SizedBox(height: 8),
              if (client.ownerName != null)
                AppAvatar(name: client.ownerName, avatar: client.ownerAvatar, size: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsSkeleton extends StatelessWidget {
  const _ClientsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          const AppCard(
            padding: EdgeInsets.all(13),
            radius: 18,
            child: Row(
              children: [
                SkeletonBox(width: 42, height: 42, radius: 13),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 120, height: 9),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}
