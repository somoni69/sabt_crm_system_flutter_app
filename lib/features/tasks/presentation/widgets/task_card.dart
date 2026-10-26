import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../domain/task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onQuickDone,
    this.showProject = true,
    this.compact = false,
    this.highlightOverdue = true,
  });

  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onQuickDone;
  final bool showProject;
  final bool compact;
  final bool highlightOverdue;

  Color get _deadlineColor {
    if (task.isDone) return AppColors.textTertiary;
    if (task.isOverdue) return AppColors.danger;
    if (task.isDueToday) return AppColors.warning;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = AppColors.priority(task.priority);
    final assignee = task.assignees.isNotEmpty ? task.assignees.first : null;

    return AppCard(
      padding: EdgeInsets.fromLTRB(13, compact ? 12 : 14, 12, compact ? 12 : 14),
      radius: 18,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: compact ? 38 : 46,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: task.isDone ? AppColors.success : priorityColor,
              borderRadius: BorderRadius.circular(99),
              boxShadow: task.isDone
                  ? null
                  : [
                      BoxShadow(
                        color: priorityColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: compact ? 13.5 : 14.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: task.isDone ? AppColors.textTertiary : AppColors.text,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    if (task.fromFounder) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.workspace_premium_rounded,
                          size: 15, color: AppColors.warning),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showProject)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.kind == 'meeting'
                                ? Icons.videocam_outlined
                                : Icons.folder_outlined,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              task.projectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!task.isDone)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.isOverdue
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                            size: 12,
                            color: _deadlineColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.deadlineLabel,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _deadlineColor,
                            ),
                          ),
                        ],
                      )
                    else
                      const AppChip(
                        label: 'Готово',
                        tone: ChipTone.success,
                        compact: true,
                        dot: true,
                      ),
                    if (task.assignees.length > 1)
                      Text(
                        '${task.assignees.length} участника',
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                if (!compact && task.progress > 0 && !task.isDone) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: task.progress / 100,
                      minHeight: 3,
                      backgroundColor: AppColors.surface3,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onQuickDone != null)
            _QuickDoneButton(done: task.isDone, onTap: onQuickDone!)
          else if (task.assigneeName != null || assignee != null)
            AppAvatar(
              name: assignee?.name ?? task.assigneeName,
              avatar: assignee?.avatar ?? task.assigneeAvatar,
              size: 28,
            ),
        ],
      ),
    );
  }
}

class _QuickDoneButton extends StatelessWidget {
  const _QuickDoneButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: done ? 'Задача выполнена' : 'Отметить выполненной',
      child: GestureDetector(
        onTap: done ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.success.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border.all(
              color: done
                  ? AppColors.success.withValues(alpha: 0.5)
                  : AppColors.borderStrong,
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 18,
            color: done ? AppColors.success : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
