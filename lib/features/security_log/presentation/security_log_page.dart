import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import 'security_log_providers.dart';

class SecurityLogPage extends ConsumerWidget {
  const SecurityLogPage({super.key});

  IconData _iconForAction(String action) {
    final a = action.toUpperCase();
    if (a.contains('LOGIN') || a.contains('AUTH')) return Icons.login_rounded;
    if (a.contains('PASSWORD')) return Icons.lock_reset_rounded;
    if (a.contains('TASK')) return Icons.check_circle_outline_rounded;
    if (a.contains('PROJECT')) return Icons.folder_open_rounded;
    if (a.contains('FINANCE') || a.contains('PAY')) return Icons.payments_outlined;
    if (a.contains('EMPLOYEE')) return Icons.badge_outlined;
    return Icons.history_rounded;
  }

  Color _colorForAction(String action) {
    final a = action.toUpperCase();
    if (a.contains('LOGIN') || a.contains('AUTH')) return AppColors.accentBright;
    if (a.contains('PASSWORD') || a.contains('DELETE')) return AppColors.danger;
    if (a.contains('TASK')) return AppColors.success;
    if (a.contains('PROJECT')) return AppColors.ice;
    if (a.contains('FINANCE')) return AppColors.warning;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(securityLogsProvider);

    return AppPage(
      header: AppHeader(
        title: 'Журнал безопасности',
        subtitle: 'Аудит действий и авторизаций',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(securityLogsProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: logsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить журнал',
              message: e.toString(),
              actionLabel: 'Повторить',
              onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return const EmptyState(
                  icon: Icons.security_rounded,
                  title: 'Записей нет',
                  message: 'Журнал действий пока пуст.',
                );
              }

              return Column(
                children: logs.map((log) {
                  final icon = _iconForAction(log.action);
                  final color = _colorForAction(log.action);
                  final dateStr = log.createdAt != null
                      ? DateFormat('dd.MM HH:mm').format(log.createdAt!)
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, size: 20, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log.action,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (log.userName != null) ...[
                                  Text(
                                    log.userName!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                if (log.details != null && log.details!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    log.details!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
