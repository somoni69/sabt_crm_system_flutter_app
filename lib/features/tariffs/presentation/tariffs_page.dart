import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../data/tariffs_repository.dart';
import '../domain/tariff.dart';
import 'tariffs_providers.dart';

class TariffsPage extends ConsumerWidget {
  const TariffsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTariffs = ref.watch(tariffsListProvider);

    return AppPage(
      header: AppHeader(
        title: 'Тарифы',
        subtitle: 'Пакеты услуг агентства',
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
        await ref.read(tariffsListProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: asyncTariffs.when(
            loading: () =>  Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: CircularProgressIndicator(color: context.palette.accent),
              ),
            ),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить тарифы',
              message: error.toString(),
              actionLabel: 'Повторить',
              onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
            data: (tariffs) {
              if (tariffs.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_offer_outlined,
                  title: 'Тарифы не найдены',
                  message: 'В системе пока нет созданных тарифов.',
                );
              }

              return Column(
                children: tariffs.map((tariff) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TariffCard(tariff: tariff),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TariffCard extends ConsumerWidget {
  const _TariffCard({required this.tariff});

  final Tariff tariff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tariff.isActive ? context.palette.borderSoft : context.palette.surface3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tariff.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: tariff.isActive,
                  activeThumbColor: context.palette.accentBright,
                  activeTrackColor: context.palette.accent,
                  onChanged: (val) async {
                    try {
                      await ref.read(tariffsRepositoryProvider).toggleActive(tariff.id);
                      ref.read(dataRevisionProvider.notifier).bump();
                    } catch (e) {
                      ref.read(dependenciesProvider).banners.show(AppBanner(
                        title: 'Ошибка изменения статуса',
                        message: e.toString(),
                        tone: BannerTone.danger,
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
          if (tariff.description != null && tariff.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tariff.description!,
              style:  TextStyle(fontSize: 12, color: context.palette.textTertiary),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${Money.somoni(tariff.monthlyPrice)} / месяц',
            style:  TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.palette.accentBright,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (tariff.storiesPerMonth > 0)
                _SpecBadge(label: '${tariff.storiesPerMonth} сторис/мес', icon: Icons.history_rounded),
              if (tariff.reelsPerMonth > 0)
                _SpecBadge(label: '${tariff.reelsPerMonth} рилс/мес', icon: Icons.video_collection_outlined),
              if (tariff.postsPerMonth > 0)
                _SpecBadge(label: '${tariff.postsPerMonth} постов/мес', icon: Icons.feed_outlined),
              if (tariff.designsPerMonth > 0)
                _SpecBadge(label: '${tariff.designsPerMonth} макетов/мес', icon: Icons.brush_outlined),
              if (tariff.shootingDaysPerMonth > 0)
                _SpecBadge(label: '${tariff.shootingDaysPerMonth} съёмочных дней', icon: Icons.camera_alt_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecBadge extends StatelessWidget {
  const _SpecBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.surface3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.palette.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style:  TextStyle(fontSize: 11, color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
