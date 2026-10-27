import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../clients/presentation/clients_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  String? _selectedStage;

  List<(String, String, Color)> get _stages => [
        ('negotiation', 'Переговор', context.palette.accentBright),
        ('meeting', 'Встреча', context.palette.ice),
        ('kp_creation', 'КП', context.palette.warning),
        ('contract', 'Договор', context.palette.success),
        ('implementation', 'Реализация', context.palette.accent),
        ('cancelled', 'Отмена', context.palette.danger),
      ];

  Future<void> _changeStage(
    BuildContext context,
    WidgetRef ref,
    String id,
    String current,
  ) async {
    final next = await showGlassSheet<String>(
      context: context,
      title: 'Этап онбординга',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final stage in _stages)
            _StageSheetRow(
              label: stage.$2,
              selected: stage.$1 == current,
              onTap: () => Navigator.of(context).pop(stage.$1),
            ),
          _StageSheetRow(
            label: 'Убрать с доски',
            danger: true,
            onTap: () => Navigator.of(context).pop(''),
          ),
        ],
      ),
    );
    if (next == null || next == current) return;
    try {
      await ref.read(clientsRepositoryProvider).update(id, {
        'onboardingStage': next.isEmpty ? null : next,
      });
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      ref
          .read(dependenciesProvider)
          .banners
          .show(
            AppBanner(
              title: 'Этап не изменился',
              message: error.message,
              tone: BannerTone.danger,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return AppPage(
      header: AppHeader(
        title: 'Онбординг клиентов',
        subtitle: 'Воронка ведения и запуск проектов',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stages filter strip
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _StageChip(
                      label: 'Все этапы',
                      selected: _selectedStage == null,
                      color: context.palette.accent,
                      onTap: () => setState(() => _selectedStage = null),
                    ),
                    ..._stages.map((st) {
                      final isSelected = _selectedStage == st.$1;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _StageChip(
                          label: st.$2,
                          selected: isSelected,
                          color: st.$3,
                          onTap: () => setState(() => _selectedStage = st.$1),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              clientsAsync.when(
                loading: () =>  Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: context.palette.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить онбординг',
                  message:
                      error is ApiException && error.message.trim().isNotEmpty
                      ? error.message
                      : 'Повторите попытку.',
                  actionLabel: 'Повторить',
                  onAction: () =>
                      ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (snap) {
                  final clients = snap.data
                      .where((c) => (c.onboardingStage ?? '').isNotEmpty)
                      .toList();
                  final filtered = clients.where((c) {
                    if (_selectedStage == null) return true;
                    return (c.onboardingStage ?? 'negotiation') ==
                        _selectedStage;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Клиентов на этом этапе нет',
                      message: 'В выбранном этапе воронки пока нет активных клиентов.',
                    );
                  }

                  return Column(
                    children: filtered.map((client) {
                      final stageKey = client.onboardingStage ?? '';
                      final stageInfo = _stages.firstWhere(
                        (s) => s.$1 == stageKey,
                        orElse: () => (
                          'negotiation',
                          'Переговор',
                          context.palette.accentBright,
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          radius: 16,
                          borderColor: context.palette.border,
                          onTap: () => context.push('/clients/${client.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      client.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.textTheme.titleMedium
                                          ?.copyWith(color: context.palette.text),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stageInfo.$3.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: stageInfo.$3.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        stageInfo.$2,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: AppTypography.family,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: stageInfo.$3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (client.contactPerson != null ||
                                  client.contactPhone != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (client.contactPerson != null)
                                      Flexible(
                                        child: _ContactBit(
                                          icon: Icons.person_outline_rounded,
                                          text: client.contactPerson!,
                                          color: context.palette.textSecondary,
                                        ),
                                      ),
                                    if (client.contactPerson != null &&
                                        client.contactPhone != null)
                                      const SizedBox(width: 12),
                                    if (client.contactPhone != null)
                                      Flexible(
                                        child: _ContactBit(
                                          icon: Icons.phone_outlined,
                                          text: client.contactPhone!,
                                          color: context.palette.textTertiary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 176,
                                  ),
                                  child: AppButton(
                                    label: 'Сменить этап',
                                    variant: AppButtonVariant.ghost,
                                    compact: true,
                                    onPressed: () => _changeStage(
                                      context,
                                      ref,
                                      client.id,
                                      stageKey,
                                    ),
                                  ),
                                ),
                              ),
                              if (client.dealPotential != null &&
                                  client.dealPotential! > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Потенциал: ${Money.somoni(client.dealPotential!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:  TextStyle(
                                    fontFamily: AppTypography.family,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textSecondary,
                                    fontFeatures: AppTypography.tabular,
                                  ),
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

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? color : context.palette.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : context.palette.borderSoft),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StageSheetRow extends StatelessWidget {
  const _StageSheetRow({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: danger ? context.palette.danger : context.palette.text,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                 Icon(
                  Icons.check_rounded,
                  color: context.palette.accentBright,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactBit extends StatelessWidget {
  const _ContactBit({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.palette.textTertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
