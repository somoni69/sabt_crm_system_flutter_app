import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../data/access_repository.dart';
import '../domain/access_models.dart';
import 'access_providers.dart';

class EmployeeAccessPage extends ConsumerStatefulWidget {
  const EmployeeAccessPage({super.key});

  @override
  ConsumerState<EmployeeAccessPage> createState() => _EmployeeAccessPageState();
}

class _EmployeeAccessPageState extends ConsumerState<EmployeeAccessPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlyCustom = false;
  bool _showRolesOverview = false;
  String? _roleFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openPermissionsSheet(BuildContext context, AccessUser user) {
    final catalog = ref.read(accessCatalogProvider).value ?? defaultAccessCatalog;

    showGlassSheet<void>(
      context: context,
      title: 'Права: ${user.name}',
      subtitle:
          '${roleLabel(user.role)}${user.secondaryRole != null ? ' + ${roleLabel(user.secondaryRole!)}' : ''}',
      child: _UserPermissionsSheet(
        user: user,
        catalog: catalog,
        onSaved: (extra, denied) async {
          Navigator.of(context).pop();
          try {
            await ref.read(accessRepositoryProvider).setAccess(
                  user.id,
                  permissions: extra,
                  denied: denied,
                );
            ref.read(dataRevisionProvider.notifier).bump();
            if (mounted) {
              ref.read(dependenciesProvider).banners.show(const AppBanner(
                    title: 'Права обновлены',
                    message: 'Персональные доступы сотрудника сохранены.',
                    tone: BannerTone.success,
                  ));
            }
          } catch (e) {
            if (mounted) {
              ref.read(dependenciesProvider).banners.show(AppBanner(
                    title: 'Ошибка сохранения прав',
                    message: e.toString(),
                    tone: BannerTone.danger,
                  ));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(accessUsersProvider);
    final catalogAsync = ref.watch(accessCatalogProvider);
    final catalog = catalogAsync.value ?? defaultAccessCatalog;
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Доступы сотрудников',
        subtitle: 'Включайте и отключайте функции для каждого сотрудника отдельно',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(accessUsersProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: usersAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: palette.accent)),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить доступы',
              message: e.toString(),
              actionLabel: 'Повторить',
              onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
            data: (allUsers) {
              final activeUsers = allUsers.where((u) => u.isActive).toList();
              final withGrants =
                  activeUsers.where((u) => u.extraPermissions.isNotEmpty).length;
              final withDenied =
                  activeUsers.where((u) => u.deniedPermissions.isNotEmpty).length;

              final filtered = activeUsers.where((u) {
                if (_onlyCustom && u.totalOverrides == 0) return false;
                if (_roleFilter != null &&
                    u.role != _roleFilter &&
                    u.secondaryRole != _roleFilter) {
                  return false;
                }
                if (_query.isEmpty) return true;
                return u.name.toLowerCase().contains(_query) ||
                    u.email.toLowerCase().contains(_query) ||
                    (u.position ?? '').toLowerCase().contains(_query) ||
                    roleLabel(u.role).toLowerCase().contains(_query);
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniAccessStat(
                          label: 'Активных',
                          value: '${activeUsers.length}',
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniAccessStat(
                          label: 'С доп. правами',
                          value: '$withGrants',
                          color: palette.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniAccessStat(
                          label: 'С ограничениями',
                          value: '$withDenied',
                          color: palette.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniAccessStat(
                          label: 'Функций',
                          value: '${catalog.length}',
                          color: palette.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    radius: 18,
                    onTap: () =>
                        setState(() => _showRolesOverview = !_showRolesOverview),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Роли: кто на них сидит',
                                    style: AppTypography.textTheme.titleSmall
                                        ?.copyWith(
                                      color: palette.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Нажмите на роль, чтобы отфильтровать сотрудников',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_roleFilter != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _roleFilter = null),
                                child: const Text(
                                  'Сбросить',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            Icon(
                              _showRolesOverview
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                        if (_showRolesOverview) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: roleLabels.entries.map((entry) {
                              final count = activeUsers
                                  .where((u) =>
                                      u.role == entry.key ||
                                      u.secondaryRole == entry.key)
                                  .length;
                              final selected = _roleFilter == entry.key;
                              return AppFilterChip(
                                label: entry.value,
                                count: count,
                                active: selected,
                                onTap: () => setState(() {
                                  _roleFilter = selected ? null : entry.key;
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(fontSize: 14, color: palette.text),
                          decoration: InputDecoration(
                            hintText: 'Поиск по имени, роли или почте…',
                            hintStyle: TextStyle(
                              color: palette.textTertiary,
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 20,
                              color: palette.textTertiary,
                            ),
                            filled: true,
                            fillColor: palette.surface2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppFilterChip(
                        label: 'Изменённые',
                        active: _onlyCustom,
                        icon: Icons.tune_rounded,
                        onTap: () => setState(() => _onlyCustom = !_onlyCustom),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Сотрудники не найдены',
                      message: 'Попробуйте изменить поисковый запрос или фильтр.',
                    )
                  else
                    ...filtered.map((u) {
                      final hasExtra = u.extraPermissions.isNotEmpty;
                      final hasDenied = u.deniedPermissions.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => _openPermissionsSheet(context, u),
                          padding: const EdgeInsets.all(14),
                          radius: 18,
                          child: Row(
                            children: [
                              AppAvatar(
                                name: u.name,
                                avatar: u.avatar,
                                size: 42,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            u.name,
                                            style:
                                                AppTypography.textTheme.titleMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (u.isSubAdmin) ...[
                                          const SizedBox(width: 6),
                                          const AppChip(
                                            label: 'Суб-админ',
                                            tone: ChipTone.warning,
                                            compact: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${roleLabel(u.role)}${u.secondaryRole != null ? ' + ${roleLabel(u.secondaryRole!)}' : ''}${u.position != null && u.position!.isNotEmpty ? ' · ${u.position}' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.textTertiary,
                                      ),
                                    ),
                                    if (hasExtra || hasDenied) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (hasExtra)
                                            AppChip(
                                              label:
                                                  'Персональных прав: ${u.extraPermissions.length}',
                                              tone: ChipTone.success,
                                              compact: true,
                                            ),
                                          if (hasDenied)
                                            AppChip(
                                              label:
                                                  '−${u.deniedPermissions.length} снято',
                                              tone: ChipTone.danger,
                                              compact: true,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: palette.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniAccessStat extends StatelessWidget {
  const _MiniAccessStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.number(size: 17, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _UserPermissionsSheet extends StatefulWidget {
  const _UserPermissionsSheet({
    required this.user,
    required this.catalog,
    required this.onSaved,
  });

  final AccessUser user;
  final List<AccessCapability> catalog;
  final void Function(List<String> extra, List<String> denied) onSaved;

  @override
  State<_UserPermissionsSheet> createState() => _UserPermissionsSheetState();
}

class _UserPermissionsSheetState extends State<_UserPermissionsSheet> {
  late Set<String> _extra;
  late Set<String> _denied;
  late Set<String> _rolePerms;

  @override
  void initState() {
    super.initState();
    _extra = Set<String>.from(widget.user.extraPermissions);
    _denied = Set<String>.from(widget.user.deniedPermissions);
    _rolePerms = rolePermissionsFor(
      role: widget.user.role,
      secondaryRole: widget.user.secondaryRole,
      isSubAdmin: widget.user.isSubAdmin,
    );
  }

  bool _isFromRole(AccessCapability cap) {
    return _rolePerms.contains(cap.key) ||
        cap.roles.contains(widget.user.role) ||
        (widget.user.secondaryRole != null &&
            cap.roles.contains(widget.user.secondaryRole));
  }

  bool _isEnabled(AccessCapability cap) {
    final fromRole = _isFromRole(cap);
    if (fromRole) {
      return !_denied.contains(cap.key);
    }
    return _extra.contains(cap.key);
  }

  void _toggle(AccessCapability cap) {
    final fromRole = _isFromRole(cap);
    setState(() {
      if (fromRole) {
        if (_denied.contains(cap.key)) {
          _denied.remove(cap.key);
        } else {
          _denied.add(cap.key);
        }
        _extra.remove(cap.key);
      } else {
        if (_extra.contains(cap.key)) {
          _extra.remove(cap.key);
        } else {
          _extra.add(cap.key);
        }
        _denied.remove(cap.key);
      }
    });
  }

  void _resetToRole() {
    setState(() {
      _extra.clear();
      _denied.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final grouped = <String, List<AccessCapability>>{};
    for (final item in widget.catalog) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppChip(
                    label: 'Выдано: ${_extra.length}',
                    tone: ChipTone.success,
                    compact: true,
                  ),
                  AppChip(
                    label: 'Снято: ${_denied.length}',
                    tone: ChipTone.danger,
                    compact: true,
                  ),
                ],
              ),
            ),
            if (_extra.isNotEmpty || _denied.isNotEmpty)
              TextButton.icon(
                onPressed: _resetToRole,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text(
                  'Сбросить к роли',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.52,
          ),
          child: ListView(
            shrinkWrap: true,
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: AppTypography.overline(
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                  ...entry.value.map((cap) {
                    final fromRole = _isFromRole(cap);
                    final enabled = _isEnabled(cap);
                    final isGranted = !fromRole && _extra.contains(cap.key);
                    final isRevoked = fromRole && _denied.contains(cap.key);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRevoked
                              ? palette.danger.withValues(alpha: 0.45)
                              : isGranted
                                  ? palette.success.withValues(alpha: 0.45)
                                  : palette.border,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile.adaptive(
                          dense: true,
                          value: enabled,
                          activeTrackColor: palette.accent,
                          onChanged: (_) => _toggle(cap),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cap.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.text,
                                  ),
                                ),
                              ),
                              if (cap.danger)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: AppChip(
                                    label: 'Важно',
                                    tone: ChipTone.danger,
                                    compact: true,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cap.description.isNotEmpty)
                                Text(
                                  cap.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textTertiary,
                                  ),
                                ),
                              const SizedBox(height: 3),
                              Text(
                                isRevoked
                                    ? 'Отключено вручную (было по роли)'
                                    : isGranted
                                        ? 'Выдано персонально'
                                        : fromRole
                                            ? 'Доступно по роли'
                                            : 'Не входит в роль',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isRevoked
                                      ? palette.danger
                                      : isGranted
                                          ? palette.success
                                          : palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Сохранить права',
          icon: Icons.check_rounded,
          variant: AppButtonVariant.primary,
          expand: true,
          onPressed: () => widget.onSaved(_extra.toList(), _denied.toList()),
        ),
      ],
    );
  }
}
