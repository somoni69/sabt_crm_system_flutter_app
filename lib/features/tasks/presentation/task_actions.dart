import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/app_banner.dart';
import '../domain/task.dart';
import 'tasks_providers.dart';

/// Marks the current user's part as done, or closes a single-assignee task.
Future<bool> quickCompleteTask(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
) async {
  if (task.isClosed) return true;
  final repo = ref.read(tasksRepositoryProvider);
  final deps = ref.read(dependenciesProvider);
  final multiAssignee = task.assignees.length > 1;

  try {
    if (multiAssignee) {
      await repo.markMyPartDone(task.id);
    } else {
      await repo.updateStatus(task.id, 'done');
    }
    ref.read(dataRevisionProvider.notifier).bump();
    deps.banners.show(AppBanner(
      title: multiAssignee ? 'Ваша часть отмечена' : 'Задача выполнена',
      message: task.title,
      tone: BannerTone.success,
      icon: Icons.check_circle_outline_rounded,
    ));
    return true;
  } on ApiException catch (error) {
    deps.banners.show(AppBanner(
      title: 'Не удалось завершить',
      message: error.message,
      tone: BannerTone.danger,
      icon: Icons.error_outline_rounded,
    ));
    return false;
  } catch (_) {
    deps.banners.show(const AppBanner(
      title: 'Не удалось завершить',
      message: 'Проверьте соединение и повторите.',
      tone: BannerTone.danger,
    ));
    return false;
  }
}
