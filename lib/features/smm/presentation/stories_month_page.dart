import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';

final _storiesMonthProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, ym) async {
  ref.watch(dataRevisionProvider);
  final parts = ym.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final last = DateTime(year, month + 1, 0).day;
  final raw = await ref.watch(dependenciesProvider).api.getJson('/stories/check', query: {
    'from': '$ym-01',
    'to': '$ym-${last.toString().padLeft(2, '0')}',
  });
  return asMap(raw) ?? const {};
});

class StoriesMonthPage extends ConsumerStatefulWidget {
  const StoriesMonthPage({super.key});

  @override
  ConsumerState<StoriesMonthPage> createState() => _StoriesMonthPageState();
}

class _StoriesMonthPageState extends ConsumerState<StoriesMonthPage> {
  String _ym = DateFormat('yyyy-MM').format(BizDate.today());

  void _shift(int delta) {
    final parsed = DateFormat('yyyy-MM').parse(_ym);
    setState(() {
      _ym = DateFormat('yyyy-MM').format(DateTime(parsed.year, parsed.month + delta));
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final allowed = canCheckStories(user);
    final async = ref.watch(_storiesMonthProvider(_ym));
    final label = DateFormat('LLLL yyyy', 'ru').format(DateFormat('yyyy-MM').parse(_ym));

    return AppPage(
      header: AppHeader(
        title: 'Сторис за месяц',
        subtitle: label,
        onBack: () => context.pop(),
      ),
      onRefresh: allowed
          ? () async {
              ref.read(dataRevisionProvider.notifier).bump();
              await ref.read(_storiesMonthProvider(_ym).future);
            }
          : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.chevron_left_rounded,
                      size: 34,
                      onPressed: () => _shift(-1),
                    ),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.chevron_right_rounded,
                      size: 34,
                      onPressed: () => _shift(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!allowed)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Проверки недоступны',
                  message: 'У вашей роли нет доступа к проверке сторис.',
                )
              else
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 72),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                  error: (error, _) => EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Месяц не загрузился',
                    message: error is ApiException ? error.message : 'Повторите попытку.',
                    actionLabel: 'Повторить',
                    onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                  ),
                  data: (data) {
                    final people = asList(data['people']).map(asMap).whereType<Map<String, dynamic>>().toList();
                    final totals = asMap(data['totals']) ?? const {};
                    final todayDone = asIntOr(totals['todayDone'], 0);
                    final todayTotal = asIntOr(totals['todayTotal'], 0);
                    final todayClosed = todayTotal > 0 && todayDone >= todayTotal;
                    if (people.isEmpty) {
                      return const EmptyState(
                        icon: Icons.auto_awesome_motion_rounded,
                        title: 'Отметок нет',
                        message: 'За этот месяц команда ещё не отмечала сторис.',
                        compact: true,
                      );
                    }
                    return Column(
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(14),
                          radius: 16,
                          child: Text(
                            'Сегодня закрыто $todayDone из $todayTotal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontWeight: FontWeight.w600,
                              color: todayClosed ? AppColors.success : AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final person in people) _PersonRow(person: person, today: asString(data['today'])),
                      ],
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

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.today});

  final Map<String, dynamic> person;
  final String? today;

  @override
  Widget build(BuildContext context) {
    final days = asMap(person['days']) ?? const {};
    final todayStatus = today == null ? null : asString(days[today]);
    final done = todayStatus == 'done';
    final marked = asIntOr(person['marked'], 0);
    final expected = asIntOr(person['expected'], 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        radius: 16,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asStringOr(person['name'], 'Сотрудник'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Отмечено $marked из $expected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              done ? 'Сегодня закрыто' : 'Сегодня открыто',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
