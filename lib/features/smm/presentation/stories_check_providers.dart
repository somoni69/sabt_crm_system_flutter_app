import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/story_check.dart';

final storyCheckProvider =
    FutureProvider.autoDispose.family<StoryCheckDay, String>((ref, dateKey) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return StoryCheckDay(
      date: dateKey,
      future: false,
      projects: const [],
      done: 0,
      partial: 0,
      none: 0,
    );
  }
  final deps = ref.watch(dependenciesProvider);
  final raw = await deps.cachedJson.fetch(
    userId: user.id,
    key: 'stories.check.$dateKey',
    path: '/stories/check/day',
    query: {'date': dateKey},
  );
  return StoryCheckDay.fromJson(asMap(raw) ?? const {});
});
