import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import 'smm_control_providers.dart';
import 'smm_providers.dart';

class SmmControlPage extends ConsumerWidget {
  const SmmControlPage({super.key});

  void _shiftMonth(WidgetRef ref, int delta) {
    final current = ref.read(selectedSmmControlYmProvider);
    final parts = current.split('-').map(int.parse).toList();
    final dt = DateTime(parts[0], parts[1] + delta, 1);
    ref.read(selectedSmmControlYmProvider.notifier).setYm(DateFormat('yyyy-MM').format(dt));
  }

  Color _moodColor(String? mood) {
    switch (mood) {
      case 'good':
        return AppColors.success;
      case 'meh':
        return AppColors.warning;
      case 'bad':
        return AppColors.danger;
      default:
        return AppColors.textTertiary;
    }
  }

  Future<void> _patch(WidgetRef ref, Map<String, dynamic> project, Map<String, dynamic> body) async {
    final id = asString(project['id']);
    if (id == null) return;
    try {
      await ref.read(smmRepositoryProvider).updateControl(id, body);
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Отметка не сохранилась',
            message: error.message,
            tone: BannerTone.danger,
          ));
    }
  }

  String _moodLabel(String? mood) {
    switch (mood) {
      case 'good':
        return 'Клиент доволен';
      case 'meh':
        return 'Так себе';
      case 'bad':
        return 'Недоволен';
      default:
        return 'Нет отзыва';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ym = ref.watch(selectedSmmControlYmProvider);
    final projectsAsync = ref.watch(smmControlProjectsProvider);

    DateTime parsedDate;
    try {
      final parts = ym.split('-').map(int.parse).toList();
      parsedDate = DateTime(parts[0], parts[1]);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final monthLabel = DateFormat.yMMMM('ru').format(parsedDate);

    return AppPage(
      header: AppHeader(
        title: 'Контроль SMM',
        subtitle: 'Здоровье проектов и публикации',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(smmControlProjectsProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Month switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                      onPressed: () => _shiftMonth(ref, -1),
                    ),
                    Text(
                      monthLabel.toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onPressed: () => _shiftMonth(ref, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              projectsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить контроль',
                  message: e.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (projects) {
                  if (projects.isEmpty) {
                    return const EmptyState(
                      icon: Icons.checklist_rounded,
                      title: 'Проектов нет',
                      message: 'В этом месяце нет активных SMM-проектов на контроле.',
                    );
                  }

                  return Column(
                    children: projects.map((p) {
                      final name = asStringOr(p['name'], 'Проект');
                      final mood = asString(p['mood']);
                      final moodColor = _moodColor(mood);
                      final reels = asMap(p['reels']);
                      final posts = asMap(p['posts']);
                      final reelsDone = asIntOr(reels?['done'], 0);
                      final reelsNorm = asIntOr(reels?['norm'], 0);
                      final postsDone = asIntOr(posts?['done'], 0);
                      final postsNorm = asIntOr(posts?['norm'], 0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.textTheme.titleMedium,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: moodColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _moodLabel(mood),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: moodColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _MetricPill(
                                    label: 'Рилсы',
                                    value: '$reelsDone / $reelsNorm',
                                    isDone: reelsDone >= reelsNorm && reelsNorm > 0,
                                  ),
                                  const SizedBox(width: 8),
                                  _MetricPill(
                                    label: 'Посты',
                                    value: '$postsDone / $postsNorm',
                                    isDone: postsDone >= postsNorm && postsNorm > 0,
                                  ),
                                ],
                              ),
                              if (asBool(p['canEdit'])) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final moodOption in const [
                                      ('good', 'Доволен'),
                                      ('meh', 'Так себе'),
                                      ('bad', 'Недоволен'),
                                    ])
                                      _ToggleChip(
                                        label: moodOption.$2,
                                        selected: mood == moodOption.$1,
                                        selectedColor: moodOption.$1 == 'bad' ? AppColors.danger : null,
                                        onTap: () => _patch(ref, p, {
                                          'ym': ym,
                                          'mood': mood == moodOption.$1 ? null : moodOption.$1,
                                        }),
                                      ),
                                    _ToggleChip(
                                      label: 'На связи',
                                      selected: asBool(p['contact']),
                                      onTap: () => _patch(ref, p, {
                                        'ym': ym,
                                        'contact': !asBool(p['contact']),
                                      }),
                                    ),
                                    _ToggleChip(
                                      label: 'Отчёт',
                                      selected: asBool(p['report']),
                                      onTap: () => _patch(ref, p, {
                                        'ym': ym,
                                        'report': !asBool(p['report']),
                                      }),
                                    ),
                                    _ToggleChip(
                                      label: 'Реклама',
                                      selected: asBool(asMap(p['ads'])?['running']),
                                      onTap: () => _patch(ref, p, {
                                        'ym': ym,
                                        'ads': !asBool(asMap(p['ads'])?['running']),
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final tone = selectedColor ?? AppColors.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? tone.withValues(alpha: 0.16) : AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? tone : AppColors.borderSoft),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: selected ? (selectedColor ?? AppColors.accentBright) : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.isDone,
  });

  final String label;
  final String value;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDone ? AppColors.success : AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDone ? AppColors.success : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
