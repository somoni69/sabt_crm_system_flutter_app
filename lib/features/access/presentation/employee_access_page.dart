import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openPermissionsSheet(BuildContext context, AccessUser user) {
    final catalog = ref.read(accessCatalogProvider).value ?? const [];

    showGlassSheet<void>(
      context: context,
      title: 'Права: ${user.name}',
      child: _UserPermissionsSheet(
        user: user,
        catalog: catalog,
        onSaved: (perms) async {
          Navigator.pop(context);
          try {
            await ref.read(accessRepositoryProvider).updatePermissions(user.id, perms);
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
                    title: 'Ошибка',
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

    return AppPage(
      header: AppHeader(
        title: 'Доступы сотрудников',
        subtitle: 'Персональные гранты и матрица прав',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(accessUsersProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search field
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Поиск по имени или должности…',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),

              usersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить доступы',
                  message: e.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (users) {
                  final filtered = users.where((u) {
                    if (!u.isActive) return false;
                    if (_query.isEmpty) return true;
                    return u.name.toLowerCase().contains(_query) ||
                        (u.position ?? '').toLowerCase().contains(_query) ||
                        u.role.toLowerCase().contains(_query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Сотрудники не найдены',
                      message: 'Попробуйте изменить поисковый запрос.',
                    );
                  }

                  return Column(
                    children: filtered.map((u) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _openPermissionsSheet(context, u),
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
                                      Text(u.name, style: AppTypography.textTheme.titleMedium),
                                      const SizedBox(height: 2),
                                      Text(
                                        u.position ?? u.role,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                      ),
                                      if (u.extraPermissions.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Персональных прав: ${u.extraPermissions.length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.accentBright,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.tune_rounded, size: 20, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

class _UserPermissionsSheet extends StatefulWidget {
  const _UserPermissionsSheet({
    required this.user,
    required this.catalog,
    required this.onSaved,
  });

  final AccessUser user;
  final List<AccessCapability> catalog;
  final void Function(List<String> perms) onSaved;

  @override
  State<_UserPermissionsSheet> createState() => _UserPermissionsSheetState();
}

class _UserPermissionsSheetState extends State<_UserPermissionsSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.user.extraPermissions);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Роль: ${widget.user.role}', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView(
              shrinkWrap: true,
              children: widget.catalog.map((cap) {
                final isChecked = _selected.contains(cap.key);
                return CheckboxListTile(
                  value: isChecked,
                  activeColor: AppColors.accent,
                  title: Text(cap.label, style: const TextStyle(fontSize: 13, color: AppColors.text)),
                  subtitle: Text(cap.category, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selected.add(cap.key);
                      } else {
                        _selected.remove(cap.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Сохранить изменения',
            variant: AppButtonVariant.primary,
            onPressed: () => widget.onSaved(_selected.toList()),
          ),
        ],
      ),
    );
  }
}
