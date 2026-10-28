import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';

String formatShiftMinutes(int minutes) {
  final safe = minutes < 0 ? 0 : minutes;
  final h = safe ~/ 60;
  final m = safe % 60;
  if (h == 0) return '$m м';
  return m > 0 ? '$h ч $m м' : '$h ч';
}

class WorkShiftData {
  const WorkShiftData({
    required this.state,
    required this.todayMinutes,
    required this.closedMinutes,
    required this.normMinutes,
    required this.normStart,
    required this.normEnd,
    required this.paidBreakMinutes,
    required this.isLate,
    this.openStartedAt,
    this.dayStartedLabel,
    this.pauseKind,
    this.pausedSince,
    this.segments = const [],
  });

  final String state; // 'idle' | 'working' | 'paused'
  final int todayMinutes;
  final int closedMinutes;
  final int normMinutes;
  final String normStart;
  final String normEnd;
  final int paidBreakMinutes;
  final bool isLate;
  final DateTime? openStartedAt;
  final String? dayStartedLabel;
  final String? pauseKind;
  final String? pausedSince;
  final List<Map<String, dynamic>> segments;

  int get liveMinutes {
    if (state != 'working' || openStartedAt == null) return todayMinutes;
    final diff = DateTime.now().difference(openStartedAt!).inMinutes;
    return closedMinutes + (diff > 0 ? diff : 0);
  }

  factory WorkShiftData.fromJson(Map<String, dynamic> json) {
    final open = asMap(json['open']);
    final norm = asMap(json['norm']);
    return WorkShiftData(
      state: asStringOr(json['state'], 'idle'),
      todayMinutes: asIntOr(json['todayMinutes'], 0),
      closedMinutes: asIntOr(json['closedMinutes'], 0),
      normMinutes: asIntOr(norm?['minutes'], 480),
      normStart: asStringOr(norm?['start'], '09:00'),
      normEnd: asStringOr(norm?['end'], '18:00'),
      paidBreakMinutes: asIntOr(json['paidBreakMinutes'], 0),
      isLate: asBool(json['isLate']),
      openStartedAt: BizDate.parse(open?['startedAt']),
      dayStartedLabel:
          asString(json['dayStartedLabel']) ?? asString(open?['startedLabel']),
      pauseKind: asString(json['pauseKind']),
      pausedSince: asString(json['pausedSince']),
      segments: asList(json['segments'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

final myWorkShiftProvider = FutureProvider.autoDispose<WorkShiftData>((ref) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final raw = await api.getJson('/work-shifts/my');
  return WorkShiftData.fromJson(asMap(raw) ?? const <String, dynamic>{});
});

final myWorkShiftMonthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final raw = await api.getJson('/work-shifts/my-month');
  return asMap(raw) ?? const <String, dynamic>{};
});

final myWorkShiftNoticesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(dataRevisionProvider);
  final api = ref.watch(dependenciesProvider).api;
  final raw = await api.getJson('/work-shifts/my-notices');
  return asList(raw).map(asMap).whereType<Map<String, dynamic>>().toList();
});

/// Тактильная карточка рабочей смены — отображается у всех ролей, кроме основателя.
class WorkShiftBannerCard extends ConsumerStatefulWidget {
  const WorkShiftBannerCard({super.key});

  @override
  ConsumerState<WorkShiftBannerCard> createState() =>
      _WorkShiftBannerCardState();
}

class _WorkShiftBannerCardState extends ConsumerState<WorkShiftBannerCard> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _act(String endpoint, {Map<String, dynamic>? body}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson('/work-shifts/$endpoint', body: body);
      ref.invalidate(myWorkShiftProvider);
      ref.invalidate(myWorkShiftMonthProvider);
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Смена',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } catch (_) {
      ref.read(dependenciesProvider).banners.show(
            const AppBanner(
              title: 'Смена',
              message: 'Не получилось выполнить действие',
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.role == 'founder') {
      return const SizedBox.shrink();
    }

    final shiftAsync = ref.watch(myWorkShiftProvider);
    final shift = shiftAsync.value;
    final state = shift?.state ?? 'idle';
    final minutes = shift?.liveMinutes ?? 0;
    final palette = context.palette;

    final Color accentColor = switch (state) {
      'working' => palette.success,
      'paused' => palette.warning,
      _ => palette.accentBright,
    };

    final String statusTitle = switch (state) {
      'working' => '${formatShiftMinutes(minutes)} · идёт смена',
      'paused' => 'Перерыв · ${formatShiftMinutes(minutes)}',
      _ => minutes > 0
          ? 'Смена завершена · ${formatShiftMinutes(minutes)}'
          : 'Рабочая смена не начата',
    };

    final String statusSub = switch (state) {
      'working' =>
        'Нажмите для перерыва, расписания отрезков или завершения дня',
      'paused' => 'Нажмите, чтобы продолжить работу или открыть детали смены',
      _ => 'Нажмите «Начать», чтобы запустить учёт рабочего времени',
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      borderColor: accentColor.withValues(alpha: 0.32),
      onTap: () => showWorkShiftSheet(context, ref),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            ),
            child: Icon(
              state == 'working'
                  ? Icons.timer_outlined
                  : state == 'paused'
                      ? Icons.coffee_outlined
                      : Icons.play_arrow_rounded,
              size: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        statusTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusSub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (state == 'idle')
            AppButton(
              label: 'Начать',
              icon: Icons.play_arrow_rounded,
              compact: true,
              busy: _busy,
              onPressed: () => _act('start'),
            )
          else if (state == 'paused')
            AppButton(
              label: 'Продолжить',
              icon: Icons.play_arrow_rounded,
              compact: true,
              busy: _busy,
              onPressed: () => _act('start'),
            )
          else
            AppButton(
              label: 'Смена',
              variant: ButtonVariant.secondary,
              compact: true,
              busy: _busy,
              onPressed: () => showWorkShiftSheet(context, ref),
            ),
        ],
      ),
    );
  }
}

Future<void> showWorkShiftSheet(BuildContext context, WidgetRef ref) {
  return showGlassSheet<void>(
    context: context,
    title: 'Моя смена',
    subtitle: 'Учёт рабочего времени, перерывы и график',
    child: const _WorkShiftSheetBody(),
  );
}

class _WorkShiftSheetBody extends ConsumerStatefulWidget {
  const _WorkShiftSheetBody();

  @override
  ConsumerState<_WorkShiftSheetBody> createState() =>
      _WorkShiftSheetBodyState();
}

class _WorkShiftSheetBodyState extends ConsumerState<_WorkShiftSheetBody> {
  bool _busy = false;
  bool _pausing = false;
  bool _asking = false;
  bool _fixing = false;

  String _askDate = BizDate.key(DateTime.now().add(const Duration(days: 1)));
  String _askTime = '11:00';
  final _askReasonCtrl = TextEditingController();

  String _fixField = 'start';
  String _fixTime = '09:00';
  final _fixNoteCtrl = TextEditingController();

  @override
  void dispose() {
    _askReasonCtrl.dispose();
    _fixNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _mutateShift(
    String path, {
    Map<String, dynamic>? body,
    String? successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson('/work-shifts/$path', body: body);
      ref.invalidate(myWorkShiftProvider);
      ref.invalidate(myWorkShiftMonthProvider);
      ref.invalidate(myWorkShiftNoticesProvider);
      if (mounted) {
        setState(() {
          _pausing = false;
          _asking = false;
          _fixing = false;
        });
      }
      if (successMessage != null) {
        ref.read(dependenciesProvider).banners.show(
              AppBanner(
                title: 'Моя смена',
                message: successMessage,
                tone: BannerTone.success,
              ),
            );
      }
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } catch (_) {
      ref.read(dependenciesProvider).banners.show(
            const AppBanner(
              title: 'Ошибка',
              message: 'Не удалось выполнить запрос',
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _pauseLabel(String? kind) => switch (kind) {
        'lunch' => 'Обед',
        'work' => 'По работе — выехал',
        _ => 'Личное',
      };

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(myWorkShiftProvider);
    final monthAsync = ref.watch(myWorkShiftMonthProvider);
    final noticesAsync = ref.watch(myWorkShiftNoticesProvider);
    final palette = context.palette;

    return shiftAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      ),
      error: (err, _) => InlineError(
        message: err.toString(),
        onRetry: () => ref.invalidate(myWorkShiftProvider),
      ),
      data: (shift) {
        final state = shift.state;
        final total = shift.liveMinutes;
        final normMin = shift.normMinutes > 0 ? shift.normMinutes : 480;
        final left = (normMin - total).clamp(0, normMin);
        final pct = (total / normMin).clamp(0.0, 1.0);

        final monthData = monthAsync.value ?? const <String, dynamic>{};
        final daysMap =
            asMap(asMap(monthData['item'])?['days']) ?? const <String, dynamic>{};
        final todayStr = asStringOr(monthData['today'], BizDate.todayKey());
        final todayDay = int.tryParse(todayStr.split('-').last) ?? DateTime.now().day;

        final weekDays = List.generate(7, (i) {
          final d = todayDay - 6 + i;
          final mins = d > 0 ? asIntOr(daysMap['$d'], 0) : 0;
          return (day: d, minutes: mins, isToday: d == todayDay);
        });
        final weekTotal =
            weekDays.fold<int>(0, (sum, item) => sum + item.minutes);

        final notices = noticesAsync.value ?? const <Map<String, dynamic>>[];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(15),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state == 'working'
                              ? palette.success
                              : state == 'paused'
                                  ? palette.warning
                                  : palette.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state == 'working'
                              ? 'Идёт с ${shift.dayStartedLabel ?? '—'}'
                              : state == 'paused'
                                  ? '${_pauseLabel(shift.pauseKind)} с ${shift.pausedSince ?? '—'}'
                                  : (total > 0 ? 'День завершён' : 'Смена не начата'),
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      if (shift.isLate)
                        const AppChip(
                          label: 'Опоздание',
                          tone: ChipTone.warning,
                          compact: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatShiftMinutes(total),
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          left > 0
                              ? 'до нормы ${formatShiftMinutes(normMin)} осталось ${formatShiftMinutes(left)}'
                              : 'норма ${formatShiftMinutes(normMin)} закрыта',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 12,
                            color: palette.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: palette.surface3,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.success),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        shift.normStart,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textTertiary,
                        ),
                      ),
                      if (shift.paidBreakMinutes > 0)
                        Text(
                          'перерыв ${formatShiftMinutes(shift.paidBreakMinutes)} в зачёт',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textTertiary,
                          ),
                        ),
                      Text(
                        shift.normEnd,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (state == 'idle')
              AppButton(
                label: 'Начать работу',
                icon: Icons.play_arrow_rounded,
                busy: _busy,
                expand: true,
                onPressed: () => _mutateShift('start'),
              )
            else if (_pausing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Чем занят перерыв?',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PauseOptionTile(
                    icon: Icons.coffee_outlined,
                    title: 'Обед',
                    subtitle: 'До 60 минут идёт в рабочие часы',
                    onTap: () => _mutateShift('pause', body: {'kind': 'lunch'}),
                  ),
                  const SizedBox(height: 8),
                  _PauseOptionTile(
                    icon: Icons.place_outlined,
                    title: 'По работе — выехал',
                    subtitle: 'Съёмка, встреча, банк · идёт в часы',
                    onTap: () => _mutateShift('pause', body: {'kind': 'work'}),
                  ),
                  const SizedBox(height: 8),
                  _PauseOptionTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Личное',
                    subtitle: 'В рабочие часы не идёт',
                    onTap: () =>
                        _mutateShift('pause', body: {'kind': 'personal'}),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Отмена',
                    variant: ButtonVariant.ghost,
                    expand: true,
                    onPressed: () => setState(() => _pausing = false),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: state == 'paused'
                        ? AppButton(
                            label: 'Продолжить',
                            icon: Icons.play_arrow_rounded,
                            busy: _busy,
                            expand: true,
                            onPressed: () => _mutateShift('start'),
                          )
                        : AppButton(
                            label: 'Перерыв',
                            icon: Icons.coffee_outlined,
                            variant: ButtonVariant.secondary,
                            busy: _busy,
                            expand: true,
                            onPressed: () => setState(() => _pausing = true),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Завершить',
                      icon: Icons.stop_rounded,
                      variant: ButtonVariant.danger,
                      busy: _busy,
                      expand: true,
                      onPressed: () => _mutateShift('stop'),
                    ),
                  ),
                ],
              ),
            if (shift.segments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(
                overline: 'ОТРЕЗКИ',
                title: 'Сегодня по отрезкам',
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                radius: 16,
                child: Column(
                  children: [
                    for (var i = 0; i < shift.segments.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: palette.borderSoft),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: shift.segments[i]['type'] == 'work'
                                    ? palette.success
                                    : asBool(shift.segments[i]['paid'])
                                        ? palette.warning
                                        : palette.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${shift.segments[i]['from'] ?? ''} — ${shift.segments[i]['to'] ?? 'сейчас'}'
                                '${shift.segments[i]['type'] == 'break' ? ' · ${_pauseLabel(asString(shift.segments[i]['kind'])).toLowerCase()}' : ''}',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 12.5,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              formatShiftMinutes(
                                asIntOr(shift.segments[i]['minutes'], 0),
                              ),
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (weekTotal > 0) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Отработано за 7 дней',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  Text(
                    formatShiftMinutes(weekTotal),
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (_asking)
              AppCard(
                padding: const EdgeInsets.all(14),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Приду позже — предупредить заранее',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: _askDate),
                            decoration: const InputDecoration(
                              labelText: 'Дата (ГГГГ-ММ-ДД)',
                            ),
                            onChanged: (v) => _askDate = v.trim(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: TextEditingController(text: _askTime),
                            decoration: const InputDecoration(
                              labelText: 'Время',
                            ),
                            onChanged: (v) => _askTime = v.trim(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _askReasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Причина (например, съёмка у клиента)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Отправить',
                            busy: _busy,
                            expand: true,
                            onPressed: () => _mutateShift(
                              'notices',
                              body: {
                                'date': _askDate,
                                'time': _askTime,
                                if (_askReasonCtrl.text.trim().isNotEmpty)
                                  'reason': _askReasonCtrl.text.trim(),
                              },
                              successMessage: 'Отправлено руководителю',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Отмена',
                            variant: ButtonVariant.ghost,
                            expand: true,
                            onPressed: () => setState(() => _asking = false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              AppButton(
                label: 'Приду позже — предупредить заранее',
                icon: Icons.event_note_outlined,
                variant: ButtonVariant.ghost,
                expand: true,
                onPressed: () => setState(() => _asking = true),
              ),
            if (notices.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final n in notices.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${n['date'] ?? ''} · в ${n['plannedTime'] ?? ''}'
                          '${n['reason'] != null ? ' · ${n['reason']}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      AppChip(
                        label: n['status'] == 'approved'
                            ? 'Одобрено'
                            : n['status'] == 'rejected'
                                ? 'Отказано'
                                : 'Ждёт',
                        tone: n['status'] == 'approved'
                            ? ChipTone.success
                            : n['status'] == 'rejected'
                                ? ChipTone.danger
                                : ChipTone.warning,
                        compact: true,
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            if (_fixing)
              AppCard(
                padding: const EdgeInsets.all(14),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Забыл отметить — поправить время',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppFilterChip(
                            label: 'Начало смены',
                            active: _fixField == 'start',
                            onTap: () => setState(() => _fixField = 'start'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppFilterChip(
                            label: 'Конец смены',
                            active: _fixField == 'end',
                            onTap: () => setState(() => _fixField = 'end'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: _fixTime),
                      decoration: const InputDecoration(
                        labelText: 'Время (ЧЧ:ММ)',
                      ),
                      onChanged: (v) => _fixTime = v.trim(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fixNoteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий (необязательно)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Отправить',
                            busy: _busy,
                            expand: true,
                            onPressed: () => _mutateShift(
                              'edit-request',
                              body: {
                                'field': _fixField,
                                'time': _fixTime,
                                if (_fixNoteCtrl.text.trim().isNotEmpty)
                                  'note': _fixNoteCtrl.text.trim(),
                              },
                              successMessage: 'Запрос отправлен руководителю',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Отмена',
                            variant: ButtonVariant.ghost,
                            expand: true,
                            onPressed: () => setState(() => _fixing = false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              AppButton(
                label: 'Забыл отметить — поправить время',
                icon: Icons.history_toggle_off_rounded,
                variant: ButtonVariant.ghost,
                expand: true,
                onPressed: () => setState(() => _fixing = true),
              ),
          ],
        );
      },
    );
  }
}

class _PauseOptionTile extends StatelessWidget {
  const _PauseOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      radius: 16,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 19, color: palette.accentBright),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: palette.textTertiary,
          ),
        ],
      ),
    );
  }
}
