import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../domain/app_notification.dart';
import 'notifications_providers.dart';

enum _NotificationFilter { all, unread }

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _NotificationFilter _filter = _NotificationFilter.all;
  bool _markingAll = false;

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _markAll() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final snapshot = async.value;
    final all = snapshot?.data ?? const <AppNotification>[];
    final unread = all.where((item) => !item.isRead).length;
    final filtered = _filter == _NotificationFilter.all
        ? all
        : all.where((item) => !item.isRead).toList();

    final groups = <String, List<AppNotification>>{};
    for (final notification in filtered) {
      groups.putIfAbsent(notification.groupLabel, () => []).add(notification);
    }

    final error = async.error;
    final errorMessage = error is ApiException
        ? error.message
        : 'Не удалось загрузить уведомления';

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: 'Уведомления',
        subtitle: unread > 0 ? '$unread новых' : 'Всё прочитано',
        onBack: () => context.pop(),
        actions: [
          if (unread > 0)
            AppIconButton(
              icon: Icons.done_all_rounded,
              size: 40,
              onPressed: _markingAll ? null : _markAll,
              tooltip: 'Прочитать всё',
            ),
        ],
      ),
      onRefresh: _refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassSegmentedControl<_NotificationFilter>(
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
                items: [
                  SegmentItem(
                    value: _NotificationFilter.all,
                    label: 'Все',
                    count: all.length,
                  ),
                  SegmentItem(
                    value: _NotificationFilter.unread,
                    label: 'Непрочитанные',
                    count: unread,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot?.error != null && all.isEmpty)
                InlineError(message: errorMessage, onRetry: _refresh)
              else if (async.isLoading && snapshot == null)
                const _NotificationsSkeleton()
              else if (error != null && snapshot == null)
                InlineError(message: errorMessage, onRetry: _refresh)
              else if (filtered.isEmpty)
                EmptyState(
                  icon: _filter == _NotificationFilter.unread
                      ? Icons.mark_email_read_outlined
                      : Icons.notifications_none_rounded,
                  title: _filter == _NotificationFilter.unread
                      ? 'Нет непрочитанных'
                      : 'Пока тихо',
                  message: _filter == _NotificationFilter.unread
                      ? 'Вы прочитали все уведомления. Отличная работа.'
                      : 'Здесь появятся задачи, дедлайны и события компании.',
                  compact: true,
                )
              else ...[
                if (snapshot?.error != null) ...[
                  OfflineRibbon(
                    cachedAt: snapshot?.savedAt,
                    showRetry: true,
                    onRetry: _refresh,
                  ),
                  const SizedBox(height: 14),
                ],
                for (final entry in groups.entries) ...[
                  SectionHeader(
                    title: entry.key,
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                  ),
                  for (final notification in entry.value) ...[
                    Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(notificationsRepositoryProvider)
                            .remove(notification.id)
                            .catchError((_) {});
                      },
                      child: _NotificationCard(
                        notification: notification,
                        onTap: () => ref
                            .read(notificationsRepositoryProvider)
                            .open(notification),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  ({IconData icon, Color color}) get _visual {
    final type = notification.type;
    if (type.contains('overdue') || type.contains('payment')) {
      return (icon: Icons.error_outline_rounded, color: AppColors.danger);
    }
    if (type.contains('completed') || type.contains('deadline')) {
      return (icon: Icons.check_circle_outline_rounded, color: AppColors.success);
    }
    if (type.contains('review') || type.contains('returned')) {
      return (icon: Icons.rate_review_outlined, color: AppColors.warning);
    }
    if (type.contains('task') || type.contains('project')) {
      return (icon: Icons.task_alt_rounded, color: AppColors.accentBright);
    }
    if (type.contains('stor')) {
      return (icon: Icons.auto_awesome_motion_rounded, color: AppColors.ice);
    }
    return (icon: Icons.notifications_none_rounded, color: AppColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      radius: 17,
      onTap: onTap,
      selected: !notification.isRead,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SurfaceIcon(
            icon: visual.icon,
            color: visual.color,
            size: 38,
            radius: 12,
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
                        notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: notification.isRead
                              ? AppColors.textSecondary
                              : AppColors.text,
                        ),
                      ),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.accentBright,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notification.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      notification.timeLabel,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 9.5,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    if (notification.link != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.north_east_rounded,
                          size: 10, color: AppColors.textDisabled),
                      const SizedBox(width: 3),
                      const Text(
                        'Открыть',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 9.5,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          const AppCard(
            padding: EdgeInsets.all(13),
            radius: 17,
            child: Row(
              children: [
                SkeletonBox(width: 38, height: 38, radius: 12),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 180, height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 130, height: 9),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
