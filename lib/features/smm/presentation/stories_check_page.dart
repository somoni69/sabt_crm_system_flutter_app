import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/story_check.dart';
import 'stories_check_providers.dart';

class StoriesCheckPage extends ConsumerStatefulWidget {
  const StoriesCheckPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<StoriesCheckPage> createState() => _StoriesCheckPageState();
}

class _StoriesCheckPageState extends ConsumerState<StoriesCheckPage> {
  DateTime _date = BizDate.today();

  String get _key => BizDate.key(_date);

  void _shift(int days) {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(BizDate.today())) return;
    setState(() => _date = next);
  }

  Future<void> _pickDate() async {
    final today = BizDate.today();
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 92)),
      lastDate: today,
      helpText: 'Дата проверки',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final allowed = canCheckStories(user);
    final async = ref.watch(storyCheckProvider(_key));
    final data = async.value;
    final error = async.error;
    final errorMessage = error is ApiException
        ? error.message
        : 'Не удалось загрузить проверку';

    return AppPage(
      showBottomBarSpace: widget.embedded,
      header: AppHeader(
        title: 'Проверка сторис',
        subtitle: BizDate.fullDate(_date),
        onBack: widget.embedded ? null : () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.calendar_month_outlined,
            size: 40,
            onPressed: _pickDate,
            tooltip: 'Выбрать дату',
          ),
          AppIconButton(
            icon: Icons.today_rounded,
            size: 40,
            onPressed: () => setState(() => _date = BizDate.today()),
            tooltip: 'Сегодня',
          ),
        ],
      ),
      onRefresh: allowed ? _refresh : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.embedded)
                const PageIntro(
                  overline: 'КОНТРОЛЬ КАЧЕСТВА',
                  title: 'Сторис',
                  subtitle: 'Кто закрыл дневную норму по каждому проекту.',
                ),
              if (!allowed)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Проверки недоступны',
                  message: 'У вашей роли нет доступа к проверке сторис.',
                )
              else ...[
                _DateBar(
                  date: _date,
                  onPrevious: () => _shift(-1),
                  onNext: _date.isBefore(BizDate.today()) ? () => _shift(1) : null,
                  onPick: _pickDate,
                ),
                const SizedBox(height: 14),
                if (data == null && async.isLoading)
                  const _CheckSkeleton()
                else if (data == null)
                  InlineError(message: errorMessage, onRetry: _refresh)
                else ...[
                  if (data.future) ...[
                    const InlineError(
                      message: 'Дата ещё не наступила — проверка появится после публикаций.',
                      compact: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SummaryCard(data: data),
                  const SizedBox(height: 16),
                  SectionHeader(
                    overline: 'ПРОЕКТЫ',
                    title: data.total == 0
                        ? 'Нет проектов со сторис'
                        : '${data.total} проектов',
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  if (data.projects.isEmpty)
                    const EmptyState(
                      icon: Icons.auto_awesome_motion_rounded,
                      title: 'Проверять нечего',
                      message:
                          'Нет активных SMM-проектов с нормой сторис на эту дату.',
                      compact: true,
                    )
                  else
                    for (final project in data.projects) ...[
                      _ProjectCheckCard(project: project),
                      const SizedBox(height: 9),
                    ],
                  if (data.projects.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Открыть SMM-календарь',
                      icon: Icons.auto_awesome_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        ref.read(navigationServiceProvider).requestedSection.value =
                            'work';
                        context.go('/');
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      radius: 18,
      child: Row(
        children: [
          _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(
                    BizDate.dayLabel(date),
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    BizDate.dateWithYear(date),
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _NavArrow(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 21, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final StoryCheckDay data;

  @override
  Widget build(BuildContext context) {
    final progress = data.total == 0 ? 0.0 : data.done / data.total;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2032), Color(0xFF111624), Color(0xFF171229)],
        ),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.done}',
                style: AppTypography.number(
                  size: 44,
                  color: data.allDone ? AppColors.success : AppColors.text,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ ${data.total}',
                  style: AppTypography.number(
                    size: 17,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'проектов закрыли норму',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              AppChip(
                label: data.allDone ? 'Норма' : 'Контроль',
                tone: data.allDone ? ChipTone.success : ChipTone.warning,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation(
                data.allDone ? AppColors.success : AppColors.ice,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Count(
                label: 'Готово',
                value: data.done,
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 14),
              _Count(
                label: 'Частично',
                value: data.partial,
                color: AppColors.warning,
                icon: Icons.contrast_rounded,
              ),
              const SizedBox(width: 14),
              _Count(
                label: 'Не отмечено',
                value: data.none,
                color: AppColors.danger,
                icon: Icons.radio_button_unchecked_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: AppTypography.tabular,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 9.5,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _ProjectCheckCard extends StatelessWidget {
  const _ProjectCheckCard({required this.project});

  final StoryCheckProject project;

  @override
  Widget build(BuildContext context) {
    final progress = project.target <= 0
        ? 0.0
        : (project.actual / project.target).clamp(0.0, 1.0);
    final color = project.isDone
        ? AppColors.success
        : project.isPartial
            ? AppColors.warning
            : AppColors.danger;
    final label = project.isDone
        ? 'Норма закрыта'
        : project.isPartial
            ? 'Частично'
            : 'Не отмечено';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              AppChip(label: label, tone: _tone(color), compact: true),
              const SizedBox(width: 8),
              Text(
                '${project.actual}/${project.target}',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (project.posters.isNotEmpty) ...[
                AvatarStack(
                  people: [
                    for (final poster in project.posters.take(4))
                      (name: poster.name, avatar: null),
                  ],
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.posters
                        .take(2)
                        .map((poster) => '${poster.name.split(' ').first} +${poster.count}')
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ] else ...[
                const Icon(Icons.person_off_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Никто не отметил сторис',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
              if (!project.isDone)
                Text(
                  'не хватает ${project.missing}',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static ChipTone _tone(Color color) {
    if (color == AppColors.success) return ChipTone.success;
    if (color == AppColors.warning) return ChipTone.warning;
    return ChipTone.danger;
  }
}

class _CheckSkeleton extends StatelessWidget {
  const _CheckSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140, height: 40),
              SizedBox(height: 14),
              SkeletonBox(height: 6, radius: 99),
            ],
          ),
        ),
        SizedBox(height: 14),
        SkeletonBox(height: 110, radius: 18),
        SizedBox(height: 9),
        SkeletonBox(height: 110, radius: 18),
      ],
    );
  }
}
