import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_range_key.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../calendar/presentation/widgets/month_grid.dart';
import '../domain/smm_models.dart';
import 'content_form_sheet.dart';
import 'smm_providers.dart';
import 'story_sheet.dart';

class SmmPage extends ConsumerStatefulWidget {
  const SmmPage({super.key});

  @override
  ConsumerState<SmmPage> createState() => _SmmPageState();
}

class _SmmPageState extends ConsumerState<SmmPage> {
  MonthKey _month = MonthKey.current();
  DateTime _selected = BizDate.today();

  void _shiftMonth(int delta) {
    final next = _month.add(delta);
    setState(() {
      _month = next;
      _selected = next.isCurrent ? BizDate.today() : next.start;
    });
  }

  void _goToday() {
    final today = BizDate.today();
    setState(() {
      _month = MonthKey.of(today);
      _selected = today;
    });
  }

  Color _colorOf(SmmEvent event) {
    if (event.isShootSession || event.prepStage != null) return context.palette.warning;
    if (event.isStory) return context.palette.ice;
    if (event.isReel) return context.palette.accent;
    if (event.isDesign) return context.palette.info;
    return context.palette.accentBright;
  }

  IconData _iconOf(SmmEvent event) {
    if (event.isShootSession) return Icons.photo_camera_outlined;
    if (event.prepStage == 'edit') return Icons.content_cut_rounded;
    if (event.prepStage == 'design') return Icons.brush_outlined;
    if (event.prepStage == 'shoot') return Icons.videocam_outlined;
    if (event.isStory) return Icons.auto_awesome_motion_rounded;
    if (event.isReel) return Icons.movie_outlined;
    if (event.isDesign) return Icons.image_outlined;
    return Icons.article_outlined;
  }

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _scheduleBacklog(SmmBacklogItem item) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2024),
      lastDate: BizDate.today().add(const Duration(days: 365 * 3)),
      helpText: 'Запланировать на дату',
      cancelText: 'Отмена',
      confirmText: 'Поставить',
    );
    if (date == null || !mounted) return;

    final deps = ref.read(dependenciesProvider);
    try {
      if (item.itemId != null) {
        await ref.read(smmRepositoryProvider).moveContentItem(
              itemId: item.itemId!,
              date: date,
            );
      } else if (item.shootId != null) {
        await ref.read(smmRepositoryProvider).updateShootSession(
              item.shootId!,
              date: date,
            );
      } else {
        return;
      }
      ref.read(dataRevisionProvider.notifier).bump();
      deps.banners.show(AppBanner(
        title: 'Запланировано',
        message: '${item.displayTitle} · ${BizDate.dateShort(date)}',
        tone: BannerTone.success,
      ));
    } on ApiException catch (error) {
      deps.banners.show(AppBanner(
        title: 'Не удалось перенести',
        message: error.message,
        tone: BannerTone.danger,
      ));
    }
  }

  void _openEvent(SmmEvent event, SmmCalendar? calendar, bool canEdit) {
    if (canEdit && event.itemId != null && event.prepStage == null) {
      showContentForm(
        context,
        ref,
        event: event,
        project: calendar?.projectOf(event.projectId),
      );
    } else {
      showGlassSheet<void>(
        context: context,
        title: event.displayTitle,
        subtitle: '${event.projectName} · ${event.contentTypeLabel}',
        child: _SmmEventSheet(
          event: event,
          canEdit: canEdit,
          onEdit: () {
            Navigator.of(context).pop();
            showContentForm(
              context,
              ref,
              event: event,
              project: calendar?.projectOf(event.projectId),
            );
          },
          onChanged: _refresh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canSee = canSeeSmmSection(user);
    final viewOnly = isSmmViewOnly(user);
    final canEdit = canSee && !viewOnly;
    final canWriteStories = isStoryWriter(user);

    final async = ref.watch(smmCalendarProvider(_month));
    final snapshot = async.value;
    final calendar = snapshot?.data;
    final events = calendar?.events ?? const <SmmEvent>[];
    final projects = calendar?.projects ?? const <SmmProject>[];
    final backlog = calendar?.backlog ?? const <SmmBacklogItem>[];
    final dayEvents = calendar?.eventsOn(_selected) ?? const <SmmEvent>[];

    final storyProjects = ref
        .watch(storyProjectsProvider)
        .where((project) => project.dailyStoriesTarget > 0)
        .toList();
    final storyLogs = ref.watch(todayStoryLogsProvider);
    final storyDone = storyLogs.fold<int>(0, (sum, log) => sum + log.storiesCount);
    final storyTarget =
        storyProjects.fold<int>(0, (sum, project) => sum + project.dailyStoriesTarget);

    final error = async.error;
    final errorMessage =
        error is ApiException ? error.message : 'Не удалось загрузить SMM-календарь';

    final markers = <String, List<Color>>{};
    for (final event in events) {
      final key = BizDate.key(event.date);
      final color = _colorOf(event);
      final list = markers.putIfAbsent(key, () => []);
      if (!list.contains(color) && list.length < 3) list.add(color);
    }

    return AppPage(
      header: AppHeader(
        title: 'SMM',
        subtitle: '${BizDate.monthNominative(_month.start)} ${_month.year}',
        actions: [
          AppIconButton(
            icon: Icons.today_rounded,
            size: 40,
            onPressed: _goToday,
            tooltip: 'Сегодня',
          ),
          if (canEdit)
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              onPressed: () => showContentForm(
                context,
                ref,
                date: _selected,
                project: projects.isEmpty ? null : projects.first,
              ),
              tooltip: 'Добавить контент',
            ),
        ],
      ),
      onRefresh: canSee ? _refresh : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canSee)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'SMM-раздел недоступен',
                  message: 'У вашей роли нет доступа к SMM-инструментам.',
                )
              else ...[
                if (canWriteStories && storyProjects.isNotEmpty) ...[
                  _StoryStrip(
                    done: storyDone,
                    target: storyTarget,
                    onTap: () => showStorySheet(context, ref),
                  ),
                  const SizedBox(height: 14),
                ],
                if (viewOnly) ...[
                  const AppChip(
                    label: 'Режим просмотра',
                    tone: ChipTone.info,
                    icon: Icons.visibility_outlined,
                    compact: true,
                  ),
                  const SizedBox(height: 10),
                ],
                CalendarMonthBar(
                  month: _month,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onToday: _goToday,
                ),
                const SizedBox(height: 12),
                MonthGrid(
                  month: _month,
                  selected: _selected,
                  markers: markers,
                  onSelect: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  overline: BizDate.dayLabel(_selected).toUpperCase(),
                  title: 'Контент дня',
                  actionLabel: canEdit ? 'Добавить' : null,
                  onAction: canEdit
                      ? () => showContentForm(
                            context,
                            ref,
                            date: _selected,
                            project: projects.isEmpty ? null : projects.first,
                          )
                      : null,
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                ),
                if (snapshot?.error != null) ...[
                  if (events.isEmpty)
                    InlineError(message: errorMessage, onRetry: _refresh)
                  else
                    OfflineRibbon(
                      cachedAt: snapshot?.savedAt,
                      showRetry: true,
                      onRetry: _refresh,
                    ),
                  const SizedBox(height: 14),
                ],
                if (async.isLoading && snapshot == null)
                  const _SmmSkeleton()
                else if (error != null && snapshot == null)
                  InlineError(message: errorMessage, onRetry: _refresh)
                else if (dayEvents.isEmpty)
                  EmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'На этот день контента нет',
                    message: canEdit
                        ? 'Запланируйте рилс, пост или макет — он появится в календаре.'
                        : 'На выбранную дату публикаций не запланировано.',
                    actionLabel: canEdit ? 'Запланировать' : null,
                    onAction: canEdit
                        ? () => showContentForm(
                              context,
                              ref,
                              date: _selected,
                              project: projects.isEmpty ? null : projects.first,
                            )
                        : null,
                    compact: true,
                  )
                else
                  for (final event in dayEvents) ...[
                    _SmmEventRow(
                      event: event,
                      color: _colorOf(event),
                      icon: _iconOf(event),
                      onTap: () => _openEvent(event, calendar, canEdit),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (canEdit && backlog.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionHeader(
                    overline: 'НЕ ЗАПЛАНИРОВАНО',
                    title: 'Заготовки',
                    actionLabel: '${backlog.length}',
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  for (final item in backlog.take(8)) ...[
                    _BacklogRow(
                      item: item,
                      onSchedule: () => _scheduleBacklog(item),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 18),
                SectionHeader(
                  overline: 'ПРОЕКТЫ',
                  title: storyProjects.isEmpty ? 'SMM-проекты' : 'Проекты в работе',
                  actionLabel: 'Все',
                  onAction: () => context.push('/projects'),
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                ),
                if (projects.isEmpty)
                  const EmptyState(
                    icon: Icons.folder_off_outlined,
                    title: 'Нет SMM-проектов',
                    message: 'Проекты появятся, когда менеджеры подключат клиентов.',
                    compact: true,
                  )
                else
                  for (final project in projects.take(6)) ...[
                    _SmmProjectRow(
                      project: project,
                      onTap: () => context.push('/projects/${project.id}'),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryStrip extends StatelessWidget {
  const _StoryStrip({
    required this.done,
    required this.target,
    required this.onTap,
  });

  final int done;
  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = target > 0 && done >= target;
    final progress = target <= 0 ? 0.0 : (done / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.palette.ice.withValues(alpha: 0.16),
            context.palette.surface1,
            context.palette.accent.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: context.palette.ice.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.ice.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.ice.withValues(alpha: 0.26)),
            ),
            child:  Icon(Icons.auto_awesome_motion_rounded,
                size: 20, color: context.palette.ice),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                     Text(
                      'Сторис сегодня',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.palette.text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$done / $target',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: complete ? context.palette.success : context.palette.ice,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: context.palette.surface3,
                    valueColor: AlwaysStoppedAnimation(
                      complete ? context.palette.success : context.palette.ice,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            label: 'Внести',
            compact: true,
            variant: AppButtonVariant.secondary,
            expanded: false,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _SmmEventRow extends StatelessWidget {
  const _SmmEventRow({
    required this.event,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final SmmEvent event;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      radius: 17,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.timeLabel.isEmpty ? '—' : event.timeLabel,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(icon, size: 15, color: color),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 42,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChip(
                      label: event.contentTypeLabel,
                      tone: ChipTone.neutral,
                      compact: true,
                    ),
                    if (event.prepStage != null)
                      AppChip(
                        label: event.prepLabel,
                        tone: ChipTone.warning,
                        compact: true,
                      ),
                    if (event.isStory && event.count > 0)
                      AppChip(
                        label: '${event.count}',
                        tone: ChipTone.info,
                        compact: true,
                      ),
                    Text(
                      event.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 10.5,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
           Icon(Icons.chevron_right_rounded,
              size: 18, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}

class _BacklogRow extends StatelessWidget {
  const _BacklogRow({required this.item, required this.onSchedule});

  final SmmBacklogItem item;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
      radius: 16,
      child: Row(
        children: [
          SurfaceIcon(
            icon: item.isShoot
                ? Icons.photo_camera_outlined
                : item.contentType == 'reel'
                    ? Icons.movie_outlined
                    : Icons.image_outlined,
            color: item.isShoot ? context.palette.warning : context.palette.accentBright,
            size: 34,
            radius: 11,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.projectName} · ${item.contentTypeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.palette.accent.withValues(alpha: 0.26)),
              ),
              child:  Text(
                'В план',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.accentBright,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmmProjectRow extends StatelessWidget {
  const _SmmProjectRow({required this.project, required this.onTap});

  final SmmProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
      radius: 16,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:  BoxDecoration(
              color: context.palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.palette.text,
                        ),
                      ),
                    ),
                    if (project.mine) ...[
                      const SizedBox(width: 6),
                      const AppChip(
                        label: 'Мой',
                        tone: ChipTone.accent,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (project.normReels != null) '${project.normReels} рилс',
                    if (project.normPosts != null) '${project.normPosts} пост',
                    if (project.storiesPerMonth != null)
                      '${project.storiesPerMonth} сторис',
                    '${project.dailyStoriesTarget} в день',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
           Icon(Icons.chevron_right_rounded,
              size: 18, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}

class _SmmEventSheet extends ConsumerWidget {
  const _SmmEventSheet({
    required this.event,
    required this.canEdit,
    required this.onEdit,
    required this.onChanged,
  });

  final SmmEvent event;
  final bool canEdit;
  final VoidCallback onEdit;
  final Future<void> Function() onChanged;

  Future<void> _openLink(BuildContext context, String? link) async {
    if (link == null || link.trim().isEmpty) return;
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _markPrep(BuildContext context, WidgetRef ref) async {
    if (event.itemId == null) return;
    final deps = ref.read(dependenciesProvider);
    try {
      await ref.read(smmRepositoryProvider).markPrepDone(event.itemId!, done: true);
      await onChanged();
      deps.banners.show(const AppBanner(
        title: 'Этап готов',
        message: 'Задача подготовки закрыта.',
        tone: BannerTone.success,
      ));
      if (context.mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      deps.banners.show(AppBanner(
        title: 'Не удалось обновить',
        message: error.message,
        tone: BannerTone.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            AppChip(label: event.contentTypeLabel, tone: ChipTone.accent, compact: true),
            if (event.prepStage != null)
              AppChip(
                label: event.prepLabel,
                tone: ChipTone.warning,
                compact: true,
              ),
            if (event.status != null)
              AppChip(
                label: _statusLabel(event.status!),
                tone: event.isDone ? ChipTone.success : ChipTone.info,
                compact: true,
              ),
            if (event.timeLabel.isNotEmpty)
              AppChip(
                label: event.timeLabel,
                tone: ChipTone.neutral,
                icon: Icons.schedule_rounded,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          radius: 16,
          child: Column(
            children: [
              KeyValueRow(
                label: 'Проект',
                value: event.projectName,
                icon: Icons.folder_outlined,
              ),
               Divider(height: 1, color: context.palette.borderSoft),
              KeyValueRow(
                label: 'Дата',
                value:
                    '${BizDate.fullDate(event.date)} · ${event.timeLabel.isEmpty ? 'весь день' : event.timeLabel}',
                icon: Icons.event_outlined,
              ),
              if (event.location != null) ...[
                 Divider(height: 1, color: context.palette.borderSoft),
                KeyValueRow(
                  label: 'Место',
                  value: event.location!,
                  icon: Icons.place_outlined,
                ),
              ],
            ],
          ),
        ),
        if (event.scriptText != null && event.scriptText!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
           Text(
            'СЦЕНАРИЙ',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.palette.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            event.scriptText!,
            style:  TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              height: 1.55,
              color: context.palette.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (canEdit && event.itemId != null && event.prepStage == null)
          AppButton(
            label: 'Редактировать позицию',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        if (canEdit && event.itemId != null && event.prepStage != null) ...[
          AppButton(
            label: 'Отметить этап готовым',
            icon: Icons.check_rounded,
            onPressed: () => _markPrep(context, ref),
          ),
          const SizedBox(height: 8),
        ],
        if (event.taskId != null) ...[
          const SizedBox(height: 8),
          AppButton(
            label: 'Открыть задачу',
            icon: Icons.arrow_forward_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/tasks/${event.taskId}');
            },
          ),
        ],
        if (event.fileLink != null) ...[
          const SizedBox(height: 8),
          AppButton(
            label: 'Открыть материал',
            icon: Icons.open_in_new_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => _openLink(context, event.fileLink),
          ),
        ],
      ],
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'planned' => 'Запланировано',
        'preparing' => 'Готовится',
        'in_production' => 'В производстве',
        'on_review' => 'На проверке',
        'on_approval' => 'На согласовании',
        'approved' => 'Согласовано',
        'published' => 'Опубликовано',
        'cancelled' => 'Отменено',
        'done' => 'Готово',
        _ => status,
      };
}

class _SmmSkeleton extends StatelessWidget {
  const _SmmSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 300, radius: 22),
        SizedBox(height: 16),
        SkeletonBox(height: 66, radius: 17),
        SizedBox(height: 8),
        SkeletonBox(height: 66, radius: 17),
      ],
    );
  }
}
