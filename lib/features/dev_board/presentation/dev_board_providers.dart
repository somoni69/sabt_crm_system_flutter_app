import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/dev_board_repository.dart';
import '../domain/dev_task.dart';

class DevBoardStatusFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void setStatus(String? status) => state = status;
}

final devBoardStatusFilterProvider =
    NotifierProvider<DevBoardStatusFilter, String?>(DevBoardStatusFilter.new);

final devBoardTasksProvider = FutureProvider.autoDispose<List<DevTask>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(devBoardRepositoryProvider);
  return repo.getTasks();
});
