import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/date_range_key.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/calendar_event.dart';

final calendarProvider =
    StreamProvider.autoDispose.family<Snapshot<List<CalendarEvent>>, DateRangeKey>(
        (ref, range) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<CalendarEvent>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'calendar.${range.fromKey}.${range.toKey}',
        path: '/calendar/events',
        query: {'from': range.fromKey, 'to': range.toKey},
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) {
              final events = asList(raw)
                  .map(asMap)
                  .whereType<Map<String, dynamic>>()
                  .map(CalendarEvent.fromJson)
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));
              return events;
            },
          ));
});

final calendarMonthProvider =
    Provider.autoDispose.family<List<CalendarEvent>, MonthKey>((ref, month) {
  final snapshot = ref.watch(calendarProvider(month.range)).value;
  return snapshot?.data ?? const [];
});

final calendarDayProvider =
    Provider.autoDispose.family<List<CalendarEvent>, ({MonthKey month, DateTime day})>((ref, arg) {
  final events = ref.watch(calendarMonthProvider(arg.month));
  return events.where((event) => BizDate.isSameDay(event.date, arg.day)).toList();
});
