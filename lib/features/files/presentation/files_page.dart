import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_env.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../projects/presentation/projects_providers.dart';
import '../data/files_repository.dart';
import '../domain/app_file.dart';
import 'files_providers.dart';

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  bool _uploading = false;

  Future<void> _pickAndUpload(String projectId) async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;

    setState(() => _uploading = true);
    try {
      await ref.read(filesRepositoryProvider).uploadFile(
            projectId: projectId,
            bytes: bytes,
            filename: picked.name,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) {
        ref.read(dependenciesProvider).banners.show(const AppBanner(
          title: 'Файл загружен',
          message: 'Файл успешно добавлен в проект.',
          tone: BannerTone.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ref.read(dependenciesProvider).banners.show(AppBanner(
          title: 'Ошибка загрузки',
          message: e.toString(),
          tone: BannerTone.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openFile(AppFile file) async {
    String url = file.url;
    if (!url.startsWith('http')) {
      final base = AppEnv.apiBaseUrl.replaceAll('/api', '');
      url = '$base$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ref.read(dependenciesProvider).banners.show(const AppBanner(
          title: 'Не удалось открыть файл',
          message: 'Проверьте подключение к сети.',
          tone: BannerTone.warning,
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(visibleProjectsProvider);
    final selectedProjectId = ref.watch(selectedFileProjectIdProvider);
    final filesAsync = ref.watch(projectFilesProvider);

    return AppPage(
      header: AppHeader(
        title: 'Файлы',
        subtitle: 'Хранилище документов и медиа',
        onBack: () => context.pop(),
        actions: [
          if (selectedProjectId != null || projects.isNotEmpty)
            AppIconButton(
              icon: Icons.upload_file_rounded,
              size: 40,
              onPressed: _uploading
                  ? null
                  : () => _pickAndUpload(selectedProjectId ?? projects.first.id),
            ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(projectFilesProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (projects.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: projects.map((p) {
                      final activeId = selectedProjectId ?? projects.first.id;
                      final isSelected = activeId == p.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            ref.read(selectedFileProjectIdProvider.notifier).setProject(p.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent : AppColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.accentBright : AppColors.borderSoft,
                              ),
                            ),
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_uploading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: AppColors.accent),
                ),
                const SizedBox(height: 8),
              ],
              filesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить файлы',
                  message: error.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (files) {
                  final activeId = selectedProjectId ?? (projects.isNotEmpty ? projects.first.id : null);
                  if (files.isEmpty) {
                    return EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: 'Файлов нет',
                      message: 'В этом проекте пока нет загруженных документов.',
                      actionLabel: activeId != null ? 'Загрузить файл' : null,
                      onAction: activeId != null ? () => _pickAndUpload(activeId) : null,
                    );
                  }

                  return Column(
                    children: files.map((file) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surface3,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _fileIcon(file.name),
                                  size: 20,
                                  color: AppColors.accentBright,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${file.sizeLabel} • ${file.uploadedByName ?? 'Пользователь'} • ${file.createdAt != null ? BizDate.dateShort(file.createdAt!) : ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                              AppIconButton(
                                icon: Icons.open_in_new_rounded,
                                size: 36,
                                onPressed: () => _openFile(file),
                                tooltip: 'Открыть',
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

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Icons.folder_zip_rounded;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }
}
