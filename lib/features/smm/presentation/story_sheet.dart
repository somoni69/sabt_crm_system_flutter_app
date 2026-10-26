import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/smm_models.dart';
import 'smm_providers.dart';

Future<void> showStorySheet(BuildContext context, WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (!isStoryWriter(user)) return;
  await showGlassSheet<void>(
    context: context,
    title: 'Сторис за сегодня',
    subtitle: 'Отметьте количество историй по каждому проекту.',
    maxHeightFactor: 0.82,
    child: const _StorySheet(),
  );
}

class _StorySheet extends ConsumerWidget {
  const _StorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(storyProjectsProvider);
    final logs = ref.watch(todayStoryLogsProvider);

    int countFor(String projectId) => logs
        .where((log) => log.projectId == projectId)
        .fold<int>(0, (sum, log) => sum + log.storiesCount);

    final totalDone = projects.fold<int>(0, (sum, p) => sum + countFor(p.id));
    final totalTarget =
        projects.fold<int>(0, (sum, p) => sum + p.dailyStoriesTarget);

    if (projects.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_motion_rounded,
        title: 'Нет проектов для сторис',
        message:
            'Сторис доступны по проектам с включённой нормой. Обратитесь к руководителю SMM.',
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          radius: 18,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Общий прогресс',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalDone из $totalTarget',
                      style: AppTypography.number(size: 22, color: AppColors.text),
                    ),
                  ],
                ),
              ),
              AppChip(
                label: BizDate.dateShort(BizDate.today()),
                tone: ChipTone.accent,
                icon: Icons.today_rounded,
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final project in projects) ...[
          _StoryProjectRow(project: project, initialCount: countFor(project.id)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}

class _StoryProjectRow extends ConsumerStatefulWidget {
  const _StoryProjectRow({required this.project, required this.initialCount});

  final SmmProject project;
  final int initialCount;

  @override
  ConsumerState<_StoryProjectRow> createState() => _StoryProjectRowState();
}

class _StoryProjectRowState extends ConsumerState<_StoryProjectRow> {
  late int _count = widget.initialCount;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _StoryProjectRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy && oldWidget.initialCount != widget.initialCount) {
      _count = widget.initialCount;
    }
  }

  Future<void> _change(int delta) async {
    if (_busy) return;
    final next = (_count + delta).clamp(0, 30);
    if (next == _count) return;
    final previous = _count;
    setState(() {
      _count = next;
      _busy = true;
    });
    try {
      await ref.read(smmRepositoryProvider).upsertStory(
            projectId: widget.project.id,
            date: BizDate.today(),
            storiesCount: next,
          );
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (_) {
      if (mounted) {
        setState(() => _count = previous);
        ref.read(dependenciesProvider).banners.show(const AppBanner(
              title: 'Не удалось сохранить',
              message: 'Проверьте соединение и повторите.',
              tone: BannerTone.danger,
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.project.dailyStoriesTarget;
    final complete = target > 0 && _count >= target;
    final progress = target <= 0 ? 0.0 : (_count / target).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      radius: 17,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complete
                          ? 'Норма закрыта'
                          : 'Цель — $target ${BizDate.plural(target, 'история', 'истории', 'историй')}',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 10,
                        color: complete ? AppColors.success : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundButton(
                icon: Icons.remove_rounded,
                onTap: _busy ? null : () => _change(-1),
              ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    '$_count',
                    style: AppTypography.number(
                      size: 24,
                      color: complete ? AppColors.success : AppColors.text,
                    ),
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                accent: true,
                onTap: _busy ? null : () => _change(1),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation(
                complete ? AppColors.success : AppColors.ice,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent ? AppColors.accent : AppColors.surface3,
            border: Border.all(
              color: accent
                  ? AppColors.accentBright.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: accent ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
