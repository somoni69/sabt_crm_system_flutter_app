import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/app_notification.dart';

final notificationsProvider =
    StreamProvider.autoDispose<Snapshot<List<AppNotification>>>((ref) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<AppNotification>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'notifications.list',
        path: '/notifications',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => asList(raw)
                .map(asMap)
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList(),
          ));
});

final unreadNotificationsProvider =
    StreamProvider.autoDispose<Snapshot<int>>((ref) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const Snapshot<int>(data: 0));
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'notifications.unread',
        path: '/notifications/unread-count',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) {
              if (raw is Map) return asIntOr(raw['count'], 0);
              return asIntOr(raw, 0);
            },
          ));
});

class NotificationsRepository {
  NotificationsRepository(this.ref);

  final Ref ref;

  Future<void> markRead(String id) async {
    final deps = ref.read(dependenciesProvider);
    await deps.api.patchJson('/notifications/$id/read');
    ref.read(dataRevisionProvider.notifier).bump();
  }

  Future<void> markAllRead() async {
    final deps = ref.read(dependenciesProvider);
    await deps.api.patchJson('/notifications/read-all');
    ref.read(dataRevisionProvider.notifier).bump();
  }

  Future<void> remove(String id) async {
    final deps = ref.read(dependenciesProvider);
    await deps.api.deleteJson('/notifications/$id');
    ref.read(dataRevisionProvider.notifier).bump();
  }

  Future<void> open(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await markRead(notification.id);
      } catch (_) {}
    }
    ref.read(navigationServiceProvider).handleLink(notification.link);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref);
});
