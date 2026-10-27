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

  Color _colorForAction(AppPalette palette, String action) {
    final a = action.toUpperCase();
    if (a.contains('LOGIN') || a.contains('AUTH')) return palette.accentBright;
    if (a.contains('PASSWORD') || a.contains('DELETE')) return palette.danger;
    if (a.contains('TASK')) return palette.success;
    if (a.contains('PROJECT')) return palette.ice;
    if (a.contains('FINANCE')) return palette.warning;
    return palette.textSecondary;
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
            loading: () =>  Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: context.palette.accent)),
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
                  final color = _colorForAction(context.palette, log.action);
                  final dateStr = log.createdAt != null
                      ? DateFormat('dd.MM HH:mm').format(log.createdAt!)
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.palette.surface1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.palette.border),
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
                                        style:  TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: context.palette.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      dateStr,
                                      style:  TextStyle(
                                        fontSize: 11,
                                        color: context.palette.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (log.userName != null) ...[
                                  Text(
                                    log.userName!,
                                    style:  TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: context.palette.textSecondary,
                                    ),
                                  ),
                                ],
                                if (log.details != null && log.details!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    log.details!,
                                    style:  TextStyle(
                                      fontSize: 11,
                                      color: context.palette.textTertiary,
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
