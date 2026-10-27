import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_prompt.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

final _projectBoardProvider = FutureProvider.autoDispose
    .family<
      ({List<Map<String, dynamic>> ads, List<Map<String, dynamic>> notes}),
      String
    >((ref, projectId) async {
      ref.watch(dataRevisionProvider);
      final api = ref.watch(dependenciesProvider).api;
      List<Map<String, dynamic>> read(dynamic raw) =>
          asList(raw is Map ? raw['data'] ?? raw['items'] ?? raw : raw)
              .map(asMap)
              .whereType<Map<String, dynamic>>()
              .toList();
      final ads = read(await api.getJson('/projects/$projectId/ads'));
      final notes = read(
        await api.getJson('/projects/$projectId/announcements'),
      );
      return (ads: ads, notes: notes);
    });

class ProjectBoardSection extends ConsumerWidget {
  const ProjectBoardSection({super.key, required this.projectId});

  final String projectId;

  bool _canAds(UserModel? user) {
    if (user == null) return false;
    return [user.role, user.secondaryRole].any(
      (role) => [
        'admin',
        'founder',
        'smm_director',
        'smm_specialist',
        'targetologist',
      ].contains(role),
    );
  }

  bool _canNotes(UserModel? user) {
    if (user == null) return false;
    return [
      user.role,
      user.secondaryRole,
    ].any((role) => ['admin', 'founder', 'smm_director'].contains(role));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (!canSeeProjects(user)) return const SizedBox.shrink();
    final async = ref.watch(_projectBoardProvider(projectId));
    final canAds = _canAds(user);
    final canNotes = _canNotes(user);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(overline: 'ВАЖНОЕ', title: 'Объявления'),
            InlineError(
              compact: true,
              message: error is ApiException && error.message.trim().isNotEmpty
                  ? error.message
                  : 'Не удалось загрузить объявления',
              onRetry: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
          ],
        ),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          SectionHeader(
            overline: 'ВАЖНОЕ',
            title: 'Объявления',
            actionLabel: canNotes ? 'Добавить' : null,
            onAction: canNotes ? () => _addNote(context, ref) : null,
          ),
          if (data.notes.isEmpty)
            const EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Объявлений нет',
              message: 'Здесь появляется то, что команда проекта должна увидеть сразу.',
              compact: true,
            )
          else
            for (final note in data.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asStringOr(note['title'], 'Объявление'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTypography.family,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            if (asString(note['description']) != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                asString(note['description'])!,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canNotes) ...[
                        const SizedBox(width: 8),
                        AppIconButton(
                          icon: Icons.delete_outline_rounded,
                          size: 44,
                          color: AppColors.danger,
                          tooltip: 'Удалить',
                          onPressed: () => _removeNote(
                            context,
                            ref,
                            asStringOr(note['id'], ''),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          SectionHeader(
            overline: 'РЕКЛАМА',
            title: 'Кампании',
            actionLabel: canAds ? 'Добавить' : null,
            onAction: canAds ? () => _addAd(context, ref) : null,
          ),
          if (data.ads.isEmpty)
            const EmptyState(
              icon: Icons.ads_click_outlined,
              title: 'Кампаний нет',
              message: 'Реклама проекта появится здесь.',
              compact: true,
            )
          else
            for (final ad in data.ads)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asStringOr(ad['title'], 'Кампания'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_status(asStringOr(ad['status'], 'planned'))}'
                        '${asDouble(ad['budget']) == null ? '' : ' · ${Money.somoni(asDouble(ad['budget']))}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _status(String status) => switch (status) {
    'running' => 'Идёт',
    'finished' => 'Завершена',
    _ => 'Запланирована',
  };

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final title = await showTextPrompt(
      context,
      title: 'Объявление',
      hint: 'Коротко, что важно',
      actionLabel: 'Опубликовать',
    );
    if (title == null || title.trim().isEmpty) return;
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson(
            '/projects/$projectId/announcements',
            body: {'title': title.trim()},
          );
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      _fail(ref, error.message);
    }
  }

  Future<void> _removeNote(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    if (id.isEmpty) return;
    await showConfirmSheet(
      context: context,
      title: 'Удалить объявление?',
      message: 'Команда больше его не увидит.',
      confirmLabel: 'Удалить',
      danger: true,
      onConfirm: () async {
        await ref
            .read(dependenciesProvider)
            .api
            .deleteJson('/projects/$projectId/announcements/$id');
        ref.read(dataRevisionProvider.notifier).bump();
      },
    );
  }

  Future<void> _addAd(BuildContext context, WidgetRef ref) async {
    final title = await showTextPrompt(
      context,
      title: 'Рекламная кампания',
      hint: 'Название',
      actionLabel: 'Дальше',
    );
    if (title == null || title.trim().isEmpty || !context.mounted) return;
    final today = BizDate.todayKey();
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson(
            '/projects/$projectId/ads',
            body: {
              'title': title.trim(),
              'channel': 'instagram',
              'status': 'planned',
              'startDate': today,
              'endDate': today,
            },
          );
      ref.read(dataRevisionProvider.notifier).bump();
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            const AppBanner(
              title: 'Кампания создана',
              message:
                  'Даты стоят на сегодня. Срок можно поправить в веб-версии.',
              tone: BannerTone.info,
            ),
          );
    } on ApiException catch (error) {
      _fail(ref, error.message);
    }
  }

  void _fail(WidgetRef ref, String message) {
    ref
        .read(dependenciesProvider)
        .banners
        .show(
          AppBanner(
            title: 'Не получилось',
            message: message,
            tone: BannerTone.danger,
          ),
        );
  }
}
