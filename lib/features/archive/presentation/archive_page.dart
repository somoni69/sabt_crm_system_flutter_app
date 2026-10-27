import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../projects/domain/project.dart';
import 'archive_providers.dart';

class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  static const _types = [
    {'label': 'Все', 'value': ''},
    {'label': 'SMM', 'value': 'smm'},
    {'label': 'Разработка', 'value': 'dev'},
    {'label': 'Брендинг', 'value': 'branding'},
    {'label': 'Продакшн', 'value': 'production'},
  ];

  Future<void> _restoreProject(BuildContext context, WidgetRef ref, ProjectModel project) async {
    await showConfirmSheet(
      context: context,
      title: 'Восстановить проект?',
      message: 'Проект «${project.name}» будет возвращён в список активных.',
      confirmLabel: 'Восстановить',
      onConfirm: () async {
        try {
          await ref.read(dependenciesProvider).api.postJson('/projects/${project.id}/restore');
          ref.read(dataRevisionProvider.notifier).bump();
          if (mounted) {
            ref.read(dependenciesProvider).banners.show(AppBanner(
              title: 'Проект восстановлен',
              message: '«${project.name}» снова в работе.',
              tone: BannerTone.success,
            ));
          }
        } catch (e) {
          if (mounted) {
            ref.read(dependenciesProvider).banners.show(AppBanner(
              title: 'Ошибка восстановления',
              message: e.toString(),
              tone: BannerTone.danger,
            ));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(archiveFilterTypeProvider);
    final asyncProjects = ref.watch(archivedProjectsProvider);

    return AppPage(
      header: AppHeader(
        title: 'Архив',
        subtitle: 'Завершённые проекты агентства',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            onPressed: () => ref.read(dataRevisionProvider.notifier).bump(),
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(archivedProjectsProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: _types.map((type) {
                    final isSelected = selectedType == type['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(archiveFilterTypeProvider.notifier).setType(type['value']!);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? context.palette.accent : context.palette.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? context.palette.accentBright : context.palette.borderSoft,
                            ),
                          ),
                          child: Text(
                            type['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              asyncProjects.when(
                loading: () =>  Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: context.palette.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить архив',
                  message: error.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (allProjects) {
                  final projects = selectedType.isEmpty
                      ? allProjects
                      : allProjects.where((p) => p.projectType == selectedType).toList();

                  if (projects.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Архив пуст',
                      message: 'В архиве нет завершённых проектов выбранного типа.',
                    );
                  }

                  return Column(
                    children: projects.map((project) {
                      final date = project.lastActivityAt ?? project.createdAt;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.palette.surface1,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: context.palette.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      project.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: context.palette.surface3,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      project.projectType,
                                      style:  TextStyle(fontSize: 10.5, color: context.palette.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              if (project.description != null && project.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  project.description!,
                                  style:  TextStyle(fontSize: 12, color: context.palette.textTertiary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Завершён: ${date != null ? BizDate.dateWithYear(date) : 'В архиве'}',
                                    style:  TextStyle(fontSize: 11, color: context.palette.textTertiary),
                                  ),
                                  Row(
                                    children: [
                                      AppButton(
                                        label: 'Восстановить',
                                        icon: Icons.unarchive_outlined,
                                        variant: AppButtonVariant.secondary,
                                        compact: true,
                                        expanded: false,
                                        onPressed: () => _restoreProject(context, ref, project),
                                      ),
                                      const SizedBox(width: 8),
                                      AppButton(
                                        label: 'Открыть',
                                        icon: Icons.arrow_forward_rounded,
                                        compact: true,
                                        expanded: false,
                                        onPressed: () => context.push('/projects/${project.id}'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
