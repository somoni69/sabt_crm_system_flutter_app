import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/employee.dart';
import 'employees_providers.dart';

class EmployeeDetailPage extends ConsumerWidget {
  const EmployeeDetailPage({super.key, required this.employeeId});

  final String employeeId;

  Future<void> _open(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (!canSeeEmployees(user)) {
      return AppPage(
        showBottomBarSpace: false,
        header: AppHeader(
          title: 'Сотрудник',
          onBack: () => context.pop(),
        ),
        slivers: const [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Профиль недоступен',
            message: 'У вашей роли нет доступа к справочнику сотрудников.',
          ),
        ],
      );
    }

    final async = ref.watch(employeeProvider(employeeId));
    final snapshot = async.value;
    final employee = snapshot?.data;

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: employee?.fullName ?? 'Сотрудник',
        subtitle: employee?.position,
        onBack: () => context.pop(),
        actions: [
          if (employee?.phone != null && employee!.phone!.trim().isNotEmpty)
            _HeaderAction(
              icon: Icons.call_outlined,
              onTap: () => _open(context, 'tel:${employee.phone}'),
            ),
          if (employee?.email.isNotEmpty ?? false)
            _HeaderAction(
              icon: Icons.mail_outline_rounded,
              onTap: () => _open(context, 'mailto:${employee!.email}'),
            ),
        ],
      ),
      onRefresh: refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (employee == null && async.isLoading)
                const _EmployeeDetailSkeleton()
              else if (employee == null)
                InlineError(
                  message: async.error is Exception
                      ? 'Не удалось загрузить профиль сотрудника'
                      : 'Профиль не найден',
                  onRetry: refresh,
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
                _HeroCard(employee: employee),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Выполнено',
                        value: '${employee.tasksCompleted}',
                        color: AppColors.success,
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _StatTile(
                        label: 'Просрочено',
                        value: '${employee.tasksOverdue}',
                        color: employee.tasksOverdue > 0
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _StatTile(
                        label: 'Возвраты',
                        value: '${employee.tasksReturned}',
                        color: AppColors.warning,
                        icon: Icons.undo_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(overline: 'КОНТАКТЫ', title: 'Связаться'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  radius: 20,
                  child: Column(
                    children: [
                      _ContactRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Почта',
                        value: employee.email,
                        onTap: () => _open(context, 'mailto:${employee.email}'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _ContactRow(
                        icon: Icons.call_outlined,
                        label: 'Телефон',
                        value: employee.phone ?? 'Не указан',
                        onTap: employee.phone == null
                            ? null
                            : () => _open(context, 'tel:${employee.phone}'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _ContactRow(
                        icon: Icons.send_outlined,
                        label: 'Telegram',
                        value: employee.telegram ?? 'Не указан',
                        onTap: employee.telegram == null
                            ? null
                            : () => _open(
                                  context,
                                  employee.telegram!.startsWith('http')
                                      ? employee.telegram
                                      : 'https://t.me/${employee.telegram!.replaceAll('@', '')}',
                                ),
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      _ContactRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Instagram',
                        value: employee.instagram ?? 'Не указан',
                        onTap: employee.instagram == null
                            ? null
                            : () => _open(
                                  context,
                                  employee.instagram!.startsWith('http')
                                      ? employee.instagram
                                      : 'https://instagram.com/${employee.instagram!.replaceAll('@', '')}',
                                ),
                      ),
                    ],
                  ),
                ),
                if (employee.bio != null && employee.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionHeader(overline: 'О СЕБЕ', title: 'Коротко'),
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    radius: 18,
                    child: Text(
                      employee.bio!,
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
                const SectionHeader(overline: 'В КОМПАНИИ', title: 'Детали'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  radius: 20,
                  child: Column(
                    children: [
                      KeyValueRow(
                        label: 'Роль в системе',
                        value: UserModel.roleLabels[employee.role] ?? employee.role,
                        icon: Icons.shield_outlined,
                      ),
                      const Divider(height: 1, color: AppColors.borderSoft),
                      KeyValueRow(
                        label: 'Отдел',
                        value: employee.department,
                        icon: Icons.apartment_rounded,
                      ),
                      if (employee.hireDate != null) ...[
                        const Divider(height: 1, color: AppColors.borderSoft),
                        KeyValueRow(
                          label: 'В команде с',
                          value: BizDate.dateWithYear(employee.hireDate!),
                          icon: Icons.event_available_outlined,
                        ),
                      ],
                      if (employee.lastActiveAt != null) ...[
                        const Divider(height: 1, color: AppColors.borderSoft),
                        KeyValueRow(
                          label: 'Последняя активность',
                          value: BizDate.relative(employee.lastActiveAt!),
                          icon: Icons.bolt_outlined,
                        ),
                      ],
                      const Divider(height: 1, color: AppColors.borderSoft),
                      KeyValueRow(
                        label: 'Индекс активности',
                        value: '${employee.activityScore}%',
                        icon: Icons.insights_rounded,
                        valueColor: employee.activityScore >= 70
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 17, color: AppColors.text),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2032), Color(0xFF111624)],
        ),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          AppAvatar(
            name: employee.fullName,
            avatar: employee.avatar,
            size: 86,
            ring: true,
          ),
          const SizedBox(height: 14),
          Text(
            employee.fullName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            employee.position,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              AppChip(
                label: employee.isActive ? 'В команде' : 'Неактивен',
                tone: employee.isActive ? ChipTone.success : ChipTone.neutral,
                dot: true,
                compact: true,
              ),
              AppChip(
                label: employee.department,
                tone: ChipTone.info,
                compact: true,
              ),
              if (employee.isSubAdmin)
                const AppChip(
                  label: 'Сооснователь',
                  tone: ChipTone.accent,
                  compact: true,
                ),
              if (employee.isStoryMaker)
                const AppChip(
                  label: 'Сторисмейкер',
                  tone: ChipTone.accent,
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.number(size: 22, color: AppColors.text)),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 9.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 11),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: onTap == null ? AppColors.textTertiary : AppColors.text,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _EmployeeDetailSkeleton extends StatelessWidget {
  const _EmployeeDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: const [
              SkeletonBox(width: 86, height: 86, radius: 43),
              SizedBox(height: 14),
              SkeletonBox(width: 180, height: 18),
              SizedBox(height: 8),
              SkeletonBox(width: 120, height: 11),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SkeletonBox(height: 80, radius: 18),
        const SizedBox(height: 14),
        const SkeletonBox(height: 180, radius: 18),
      ],
    );
  }
}
