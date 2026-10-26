
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dependencies.dart';
import '../navigation/navigation_service.dart';

/// Bumped by socket events, connectivity restore and local mutations. Every
/// cached stream watches it, which gives us one coherent refresh bus.
final dataRevisionProvider = NotifierProvider<DataRevision, int>(DataRevision.new);

class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final onlineProvider = NotifierProvider<OnlineNotifier, bool>(OnlineNotifier.new);

class OnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
    final deps = ref.watch(dependenciesProvider);
    final subscription = deps.connectivity.changes.listen((online) {
      state = online;
      if (online) ref.read(dataRevisionProvider.notifier).bump();
    });
    ref.onDispose(subscription.cancel);
    return deps.connectivity.isOnline;
  }
}

final realtimeConnectedProvider =
    NotifierProvider<RealtimeConnectedNotifier, bool>(RealtimeConnectedNotifier.new);

class RealtimeConnectedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final deps = ref.watch(dependenciesProvider);
    final subscription = deps.realtime.connectionChanges.listen((connected) {
      state = connected;
    });
    ref.onDispose(subscription.cancel);
    return deps.realtime.isConnected;
  }
}

final navigationServiceProvider = Provider<NavigationService>((ref) {
  return ref.watch(dependenciesProvider).navigation;
});

final bannerServiceProvider = Provider((ref) {
  return ref.watch(dependenciesProvider).banners;
});

final firebaseRuntimeProvider = Provider((ref) {
  return ref.watch(dependenciesProvider).firebase;
});

/// Increment both the local revision and, when requested, the shell tab.
class AppRefresh {
  AppRefresh(this.ref);

  final Ref ref;

  void bump() => ref.read(dataRevisionProvider.notifier).bump();
}
