import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../clients/presentation/clients_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  String? _selectedStage;

  static const _stages = [
    ('negotiation', 'Переговор', AppColors.accentBright),
    ('meeting', 'Встреча', AppColors.ice),
    ('kp_creation', 'КП', AppColors.warning),
    ('contract', 'Договор', AppColors.success),
    ('implementation', 'Реализация', AppColors.accent),
    ('cancelled', 'Отмена', AppColors.danger),
  ];

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
                      color: AppColors.accent,
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
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить онбординг',
                  message: e.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (snap) {
                  final clients = snap.data;
                  final filtered = clients.where((c) {
                    if (_selectedStage == null) return true;
                    return (c.onboardingStage ?? 'negotiation') == _selectedStage;
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
                      final stageKey = client.onboardingStage ?? 'negotiation';
                      final stageInfo = _stages.firstWhere(
                        (s) => s.$1 == stageKey,
                        orElse: () => ('negotiation', 'Переговор', AppColors.accentBright),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => context.push('/clients/${client.id}'),
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
                                        client.name,
                                        style: AppTypography.textTheme.titleMedium,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: stageInfo.$3.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: stageInfo.$3.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        stageInfo.$2,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: stageInfo.$3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (client.contactPerson != null || client.contactPhone != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (client.contactPerson != null) ...[
                                        const Icon(Icons.person_outline_rounded,
                                            size: 13, color: AppColors.textTertiary),
                                        const SizedBox(width: 4),
                                        Text(
                                          client.contactPerson!,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      if (client.contactPhone != null) ...[
                                        const Icon(Icons.phone_outlined,
                                            size: 13, color: AppColors.textTertiary),
                                        const SizedBox(width: 4),
                                        Text(
                                          client.contactPhone!,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                                if (client.dealPotential != null && client.dealPotential! > 0) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Потенциал: ${Money.somoni(client.dealPotential!)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
