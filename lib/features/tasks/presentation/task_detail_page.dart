import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/dependencies.dart';
import '../../../core/design/glass_surface.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/api_urls.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_prompt.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/task.dart';
import '../domain/task_file.dart';
import 'task_form_sheet.dart';
import 'tasks_providers.dart';

enum _TaskTab { overview, comments, results, files }

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _comment = TextEditingController();
  _TaskTab _tab = _TaskTab.overview;
  bool _commentBusy = false;
  bool _actionBusy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  AppDependencies get _deps => ref.read(dependenciesProvider);

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  void _showError(Object error) {
    final message = switch (error) {
      ApiException() => error.message,
      String() => error,
      _ => 'Не удалось выполнить действие',
    };
    _deps.banners.show(AppBanner(
      title: 'Ошибка',
      message: message,
      tone: BannerTone.danger,
      icon: Icons.error_outline_rounded,
    ));
  }

  void _showSuccess(String title, [String? message]) {
    _deps.banners.show(AppBanner(
      title: title,
      message: message ?? '',
      tone: BannerTone.success,
      icon: Icons.check_circle_outline_rounded,
    ));
  }

  Future<void> _runAction(Future<void> Function() action, String success) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await action();
      ref.read(dataRevisionProvider.notifier).bump();
      _showSuccess(success);
    } on ApiException catch (error) {
      _showError(error);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _complete(TaskModel task) async {
    final repo = ref.read(tasksRepositoryProvider);
    if (task.assignees.length > 1) {
      await _runAction(
        () => repo.markMyPartDone(task.id),
        'Ваша часть отмечена выполненной',
      );
    } else {
      await _runAction(
        () => repo.updateStatus(task.id, 'done'),
        'Задача завершена',
      );
    }
  }

  Future<void> _return(TaskModel task) async {
    final reason = await showTextPrompt(
      context,
      title: 'Вернуть на доработку',
      subtitle: 'Исполнитель получит причину и уведомление.',
      hint: 'Что нужно исправить?',
      actionLabel: 'Вернуть задачу',
      maxLines: 3,
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _runAction(
      () => ref.read(tasksRepositoryProvider).returnTask(task.id, reason.trim()),
      'Задача возвращена на доработку',
    );
  }

  Future<void> _sendComment(TaskModel task) async {
    final text = _comment.text.trim();
    if (text.isEmpty || _commentBusy) return;
    setState(() => _commentBusy = true);
    try {
      await ref.read(tasksRepositoryProvider).addComment(task.id, text);
      _comment.clear();
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      _showError(error);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _addResult(TaskModel task) async {
    final text = await showTextPrompt(
      context,
      title: 'Результат работы',
      subtitle: 'Опишите, что сделано, или приложите ссылку.',
      hint: 'Например: макет готов, ссылка на Figma…',
      actionLabel: 'Добавить результат',
      maxLines: 5,
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await ref.read(tasksRepositoryProvider).addResult(
            task.id,
            type: 'text',
            content: text.trim(),
          );
      ref.read(dataRevisionProvider.notifier).bump();
      _showSuccess('Результат добавлен');
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _addChecklistItem(TaskModel task) async {
    final text = await showTextPrompt(
      context,
      title: 'Новый пункт',
      hint: 'Что нужно проверить?',
      actionLabel: 'Добавить',
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await ref.read(tasksRepositoryProvider).addChecklistItem(task.id, text.trim());
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleChecklist(TaskModel task, String itemId) async {
    try {
      await ref.read(tasksRepositoryProvider).toggleChecklistItem(task.id, itemId);
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _uploadFile(TaskModel task) async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await ref.read(tasksRepositoryProvider).uploadTaskFile(
            task.id,
            bytes: bytes,
            filename: file.name,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      _showSuccess('Файл прикреплён', file.name);
    } on ApiException catch (error) {
      _showError(error);
    } catch (_) {
      _showError('Не удалось загрузить файл');
    }
  }

  Future<void> _openUrl(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final ok = await launchUrl(
        Uri.parse(raw),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _showError('Не удалось открыть ссылку');
    } catch (_) {
      _showError('Не удалось открыть ссылку');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(taskProvider(widget.taskId));
    final snapshot = async.value;
    final task = snapshot?.data;

    final canEdit = userCan(user, Perm.tasksEdit);
    final canApprove = userCan(user, Perm.tasksApprove);
    final canReturn = userCan(user, Perm.tasksReturn);
    final canUpload = userCan(user, Perm.filesUpload);

    final comments = ref.watch(taskCommentsProvider(widget.taskId)).value?.data ??
        const <TaskComment>[];
    final results = ref.watch(taskResultsProvider(widget.taskId)).value?.data ??
        const <TaskResult>[];
    final checklist = ref.watch(taskChecklistProvider(widget.taskId)).value?.data ??
        const <TaskChecklistItem>[];
    final files = ref.watch(taskFilesProvider(widget.taskId)).value?.data ??
        const <TaskFile>[];

    Widget? actionBar;
    if (task != null && !task.isClosed) {
      actionBar = _buildActionBar(task, canApprove, canReturn);
    }

    return AppPage(
      showBottomBarSpace: false,
      bottomPadding: PageInsets.bottomPlain(context) + (actionBar == null ? 0 : 82),
      header: AppHeader(
        title: 'Задача',
        subtitle: task?.projectLabel,
        onBack: () => context.pop(),
        actions: [
          if (task != null && canEdit && !task.isClosed)
            AppIconButton(
              icon: Icons.edit_outlined,
              size: 40,
              onPressed: () => showTaskForm(context, ref, task: task),
              tooltip: 'Редактировать',
            ),
          if (task != null && canReturn && !task.isClosed)
            AppIconButton(
              icon: Icons.undo_rounded,
              size: 40,
              onPressed: () => _return(task),
              tooltip: 'Вернуть на доработку',
            ),
        ],
      ),
      onRefresh: _refresh,
      floatingAction: actionBar,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: task == null
              ? _buildPlaceholder(async)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot?.error != null) ...[
                      OfflineRibbon(
                        cachedAt: snapshot?.savedAt,
                        showRetry: true,
                        onRetry: _refresh,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _TaskHero(task: task),
                    const SizedBox(height: 16),
                    AppChoiceChips<_TaskTab>(
                      selected: _tab,
                      onChanged: (value) => setState(() => _tab = value),
                      options: [
                        const AppChoice(value: _TaskTab.overview, label: 'Обзор'),
                        AppChoice(
                          value: _TaskTab.comments,
                          label: comments.isEmpty ? 'Чат' : 'Чат ${comments.length}',
                        ),
                        AppChoice(
                          value: _TaskTab.results,
                          label: results.isEmpty ? 'Итоги' : 'Итоги ${results.length}',
                        ),
                        AppChoice(
                          value: _TaskTab.files,
                          label: files.isEmpty ? 'Файлы' : 'Файлы ${files.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    switch (_tab) {
                      _TaskTab.overview => _buildOverview(task, checklist),
                      _TaskTab.comments => _buildComments(task, comments),
                      _TaskTab.results => _buildResults(task, results, canEdit),
                      _TaskTab.files => _buildFiles(task, files, canUpload),
                    },
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(AsyncValue<dynamic> async) {
    if (async.hasError) {
      final error = async.error;
      return InlineError(
        message: error is ApiException ? error.message : 'Задача не найдена',
        onRetry: _refresh,
      );
    }
    return const Column(
      children: [
        SkeletonBox(height: 120, radius: 22),
        SizedBox(height: 14),
        SkeletonBox(height: 44, radius: 15),
        SizedBox(height: 14),
        SkeletonBox(height: 220, radius: 22),
      ],
    );
  }

  Widget _buildOverview(TaskModel task, List<TaskChecklistItem> checklist) {
    final acceptance = task.acceptanceCriteria;
    final acceptanceDone = acceptance.where((item) => item.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.description != null && task.description!.trim().isNotEmpty) ...[
          SectionHeader(
            overline: 'ОПИСАНИЕ',
            title: 'Что нужно сделать',
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.all(15),
            radius: 18,
            child: Text(
              task.description!,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13.5,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        const SectionHeader(
          overline: 'ДЕТАЛИ',
          title: 'Параметры',
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          radius: 18,
          child: Column(
            children: [
              KeyValueRow(
                label: 'Проект',
                value: task.projectLabel,
                icon: Icons.folder_outlined,
                onTap: task.projectId == null
                    ? null
                    : () => context.push('/projects/${task.projectId}'),
              ),
              const Divider(height: 1, color: AppColors.borderSoft),
              KeyValueRow(
                label: 'Срок',
                value: task.deadlineLabel,
                icon: Icons.schedule_rounded,
                valueColor: task.isOverdue
                    ? AppColors.danger
                    : task.isDueToday
                        ? AppColors.warning
                        : null,
              ),
              const Divider(height: 1, color: AppColors.borderSoft),
              KeyValueRow(
                label: 'Автор',
                value: task.createdByName ?? '—',
                icon: Icons.person_outline_rounded,
              ),
              if (task.estimatedHours > 0 || task.loggedHours > 0) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Часы',
                  value:
                      '${Money.hours(task.loggedHours)} из ${Money.hours(task.estimatedHours)}',
                  icon: Icons.timer_outlined,
                ),
              ],
              if (task.createdAt != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Создана',
                  value: BizDate.relative(task.createdAt!),
                  icon: Icons.history_rounded,
                ),
              ],
            ],
          ),
        ),
        if (task.assignees.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionHeader(
            overline: 'КОМАНДА',
            title: task.assignees.length > 1 ? 'Исполнители' : 'Исполнитель',
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            radius: 18,
            child: Column(
              children: [
                for (var i = 0; i < task.assignees.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.borderSoft),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        AppAvatar(
                          name: task.assignees[i].name,
                          avatar: task.assignees[i].avatar,
                          size: 34,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.assignees[i].name,
                                style: const TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              if (task.assignees[i].note != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  task.assignees[i].note!,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.family,
                                    fontSize: 10.5,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (task.assignees[i].isDone)
                          const AppChip(
                            label: 'Готово',
                            tone: ChipTone.success,
                            compact: true,
                            dot: true,
                          )
                        else
                          const AppChip(
                            label: 'В работе',
                            tone: ChipTone.neutral,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (acceptance.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionHeader(
            overline: 'КРИТЕРИИ',
            title: 'Приёмка',
            actionLabel: '$acceptanceDone/${acceptance.length}',
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          AppCard(
            padding: const EdgeInsets.all(15),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: acceptance.isEmpty ? 0 : acceptanceDone / acceptance.length,
                    minHeight: 4,
                    backgroundColor: AppColors.surface3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in acceptance)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 17,
                          color: item.done ? AppColors.success : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12.5,
                              height: 1.4,
                              color: item.done
                                  ? AppColors.textTertiary
                                  : AppColors.textSecondary,
                              decoration: item.done ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        SectionHeader(
          overline: 'ЧЕК-ЛИСТ',
          title: 'Этапы',
          actionLabel: 'Добавить',
          onAction: () => _addChecklistItem(task),
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          radius: 18,
          child: checklist.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Чек-лист пока пуст. Добавьте шаги, чтобы не потерять детали.',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < checklist.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.borderSoft),
                      InkWell(
                        onTap: () => _toggleChecklist(task, checklist[i].id),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                checklist[i].isDone
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 19,
                                color: checklist[i].isDone
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  checklist[i].text,
                                  style: TextStyle(
                                    fontFamily: AppTypography.family,
                                    fontSize: 12.5,
                                    color: checklist[i].isDone
                                        ? AppColors.textTertiary
                                        : AppColors.textSecondary,
                                    decoration: checklist[i].isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildComments(TaskModel task, List<TaskComment> comments) {
    final me = ref.watch(currentUserProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (comments.isEmpty)
          const EmptyState(
            icon: Icons.forum_outlined,
            title: 'Обсуждение пустое',
            message: 'Задайте вопрос или поделитесь деталями с командой.',
            compact: true,
          )
        else
          for (final comment in comments) ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
              radius: 17,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(
                    name: comment.authorName ?? 'Сотрудник',
                    avatar: comment.authorAvatar,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                comment.authorId == me?.id
                                    ? 'Вы'
                                    : comment.authorName ?? 'Сотрудник',
                                style: const TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (comment.createdAt != null)
                              Text(
                                BizDate.relative(comment.createdAt!),
                                style: const TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 9.5,
                                  color: AppColors.textDisabled,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          comment.message,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 6),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          radius: 18,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _comment,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.text,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Написать комментарий…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _commentBusy ? null : () => _sendComment(task),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _commentBusy
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded,
                          size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResults(TaskModel task, List<TaskResult> results, bool canEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.isClosed) ...[
          AppCard(
            padding: const EdgeInsets.all(14),
            radius: 18,
            child: Row(
              children: [
                const SurfaceIcon(
                  icon: Icons.verified_outlined,
                  color: AppColors.success,
                  size: 38,
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Задача завершена. Результаты сохранены в истории проекта.',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (results.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Результатов пока нет',
            message: 'Приложите ссылку, файл или описание выполненной работы.',
            compact: true,
          )
        else
          for (final result in results) ...[
            AppCard(
              padding: const EdgeInsets.all(14),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        name: result.authorName ?? 'Сотрудник',
                        avatar: result.authorAvatar,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.authorName ?? 'Сотрудник',
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      AppChip(
                        label: result.type == 'file' ? 'Файл' : 'Текст',
                        tone: ChipTone.info,
                        compact: true,
                      ),
                      if (canEdit)
                        GestureDetector(
                          onTap: () => showConfirmSheet(
                            context: context,
                            title: 'Удалить результат?',
                            message: 'Действие нельзя отменить.',
                            confirmLabel: 'Удалить',
                            danger: true,
                            onConfirm: () async {
                              try {
                                await ref
                                    .read(tasksRepositoryProvider)
                                    .deleteResult(task.id, result.id);
                                ref.read(dataRevisionProvider.notifier).bump();
                              } on ApiException catch (error) {
                                _showError(error);
                              }
                            },
                          ),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 16, color: AppColors.textTertiary),
                          ),
                        ),
                    ],
                  ),
                  if (result.content.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      result.content,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (result.filePath != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _openUrl(ApiUrls.file(result.filePath)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file_rounded,
                                size: 14, color: AppColors.accentBright),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                result.fileName ?? 'Открыть файл',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accentBright,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
        if (!task.isClosed) ...[
          const SizedBox(height: 4),
          AppButton(
            label: 'Добавить результат',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _addResult(task),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFiles(TaskModel task, List<TaskFile> files, bool canUpload) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (files.isEmpty)
          const EmptyState(
            icon: Icons.cloud_upload_outlined,
            title: 'Файлов пока нет',
            message: 'Прикрепите макеты, видео или документы к задаче.',
            compact: true,
          )
        else
          for (final file in files) ...[
            AppCard(
              padding: const EdgeInsets.all(12),
              radius: 16,
              onTap: () => _openUrl(file.url),
              child: Row(
                children: [
                  SurfaceIcon(
                    icon: file.isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 38,
                    radius: 12,
                    color: file.isImage ? AppColors.ice : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.originalName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (file.sizeLabel.isNotEmpty) file.sizeLabel,
                            if (file.uploadedByName != null) file.uploadedByName!,
                            if (file.createdAt != null)
                              BizDate.dateShort(file.createdAt!),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.download_rounded,
                      size: 18, color: AppColors.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        if (canUpload && !task.isClosed) ...[
          const SizedBox(height: 4),
          AppButton(
            label: 'Прикрепить файл',
            icon: Icons.upload_file_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _uploadFile(task),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionBar(TaskModel task, bool canApprove, bool canReturn) {
    if (task.status == 'on_review' && !canApprove) {
      return GlassSurface(
        radius: 22,
        strong: true,
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded,
                size: 18, color: AppColors.warning),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Ожидает проверки руководителя',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (canReturn)
              AppButton(
                label: 'Вернуть',
                icon: Icons.undo_rounded,
                compact: true,
                expanded: false,
                variant: AppButtonVariant.secondary,
                onPressed: _actionBusy ? null : () => _return(task),
              ),
          ],
        ),
      );
    }

    final primaryLabel = task.status == 'on_review' && canApprove
        ? 'Принять работу'
        : task.assignees.length > 1
            ? 'Моя часть готова'
            : 'Завершить';
    final primaryIcon = task.status == 'on_review' && canApprove
        ? Icons.verified_rounded
        : Icons.check_rounded;

    Future<void> primary() async {
      if (task.status == 'on_review' && canApprove) {
        await _runAction(
          () => ref.read(tasksRepositoryProvider).approve(task.id),
          'Работа принята',
        );
      } else {
        await _complete(task);
      }
    }

    final showSecondary = task.status == 'new' ||
        ((task.status == 'in_progress' || task.status == 'on_review') && canReturn);

    return GlassSurface(
      radius: 22,
      strong: true,
      padding: const EdgeInsets.all(7),
      child: Row(
        children: [
          if (showSecondary) ...[
            Expanded(
              child: AppButton(
                label: task.status == 'new' ? 'В работу' : 'Вернуть',
                icon: task.status == 'new'
                    ? Icons.play_arrow_rounded
                    : Icons.undo_rounded,
                compact: true,
                variant: AppButtonVariant.secondary,
                onPressed: _actionBusy
                    ? null
                    : task.status == 'new'
                        ? () => _runAction(
                              () => ref
                                  .read(tasksRepositoryProvider)
                                  .updateStatus(task.id, 'in_progress'),
                              'Задача взята в работу',
                            )
                        : () => _return(task),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: primaryLabel,
              icon: primaryIcon,
              compact: true,
              loading: _actionBusy,
              onPressed: _actionBusy ? null : primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskHero extends StatelessWidget {
  const _TaskHero({required this.task});

  final TaskModel task;

  static String _statusLabel(String status) => switch (status) {
        'new' => 'Новая',
        'in_progress' => 'В работе',
        'on_review' => 'На проверке',
        'done' => 'Готово',
        'cancelled' => 'Отменена',
        'returned' => 'Возвращена',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2032), Color(0xFF111624), Color(0xFF171229)],
          stops: [0, 0.6, 1],
        ),
        border: Border.all(
          color: task.isOverdue
              ? AppColors.danger.withValues(alpha: 0.28)
              : AppColors.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              StatusBadge(
                status: task.status,
                label: _statusLabel(task.status),
              ),
              AppChip(
                label: (const {
                      'low': 'Низкий',
                      'medium': 'Средний',
                      'high': 'Высокий',
                      'critical': 'Критичный',
                    }[task.priority]) ??
                    task.priority,
                tone: switch (task.priority) {
                  'critical' => ChipTone.danger,
                  'high' => ChipTone.warning,
                  'medium' => ChipTone.info,
                  _ => ChipTone.neutral,
                },
                dot: true,
                compact: true,
              ),
              if (task.isMeeting)
                const AppChip(
                  label: 'Встреча',
                  tone: ChipTone.info,
                  icon: Icons.videocam_outlined,
                  compact: true,
                ),
              if (task.isPersonal)
                const AppChip(
                  label: 'Личная',
                  tone: ChipTone.neutral,
                  compact: true,
                ),
              if (task.fromFounder)
                const AppChip(
                  label: 'От руководства',
                  tone: ChipTone.accent,
                  icon: Icons.workspace_premium_rounded,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            task.title,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 22,
              height: 1.22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                task.isOverdue
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                size: 14,
                color: task.isOverdue
                    ? AppColors.danger
                    : task.isDueToday
                        ? AppColors.warning
                        : AppColors.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                task.deadlineLabel,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: task.isOverdue
                      ? AppColors.danger
                      : task.isDueToday
                          ? AppColors.warning
                          : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.folder_outlined,
                  size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  task.projectLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
