
/// Business timezone is Asia/Dushanbe (UTC+5, no DST). All day-grouping and
/// "today/overdue" decisions use this wall clock, regardless of device tz.
abstract final class BizDate {
  static const Duration offset = Duration(hours: 5);

  /// Returns an unflagged DateTime whose components are the business wall
  /// clock in Dushanbe. Never convert this value with toLocal() again.
  static DateTime _wallClock(DateTime instant) {
    final shifted = instant.toUtc().add(offset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
    );
  }

  static DateTime now() => _wallClock(DateTime.now());

  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  static String todayKey() => key(today());

  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return _wallClock(raw);
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (!value.contains('T')) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return _wallClock(parsed);
  }

  /// Converts a business wall-clock value to the ISO string the backend stores
  /// (UTC instant). `DateTime(2026,10,26,18,00)` → `...T13:00:00.000Z`.
  static String toApiIso(DateTime business) {
    final utc = DateTime.utc(
      business.year,
      business.month,
      business.day,
      business.hour,
      business.minute,
      business.second,
    ).subtract(offset);
    return utc.toIso8601String();
  }

  static String toApiDate(DateTime business) => key(business);

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime? date) => isSameDay(date, now());

  static bool isTomorrow(DateTime? date) {
    if (date == null) return false;
    final tomorrow = today().add(const Duration(days: 1));
    return isSameDay(date, tomorrow);
  }

  static bool isYesterday(DateTime? date) {
    if (date == null) return false;
    final yesterday = today().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  static int daysBetween(DateTime from, DateTime to) {
    final a = startOfDay(from);
    final b = startOfDay(to);
    return b.difference(a).inDays;
  }

  static DateTime weekStart(DateTime date) {
    final day = startOfDay(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  static DateTime monthEnd(DateTime date) => DateTime(date.year, date.month + 1, 0);

  static int daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

  static List<DateTime> monthGrid(DateTime month) {
    final first = monthStart(month);
    final start = weekStart(first);
    final last = monthEnd(month);
    final end = weekStart(last).add(const Duration(days: 6));
    final days = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      days.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  static const List<String> _monthsFull = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static const List<String> _monthsNominative = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const List<String> _monthsShort = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  static const List<String> _weekdaysShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

  static const List<String> _weekdaysFull = [
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];

  static String monthNominative(DateTime date) => _monthsNominative[date.month - 1];
  static String monthShort(DateTime date) => _monthsShort[date.month - 1];
  static String weekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];
  static String weekdayFull(DateTime date) => _weekdaysFull[date.weekday - 1];

  static String dateShort(DateTime date) => '${date.day} ${monthShort(date)}';

  static String dateLong(DateTime date) => '${date.day} ${_monthsFull[date.month - 1]}';

  static String dateWithYear(DateTime date) => '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';

  static String fullDate(DateTime date) =>
      '${weekdayFull(date)}, ${date.day} ${_monthsFull[date.month - 1]}';

  static String time(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static bool isMidnight(DateTime date) => date.hour == 0 && date.minute == 0;

  static String dayLabel(DateTime date) {
    if (isToday(date)) return 'Сегодня';
    if (isTomorrow(date)) return 'Завтра';
    if (isYesterday(date)) return 'Вчера';
    return '${weekdayShort(date)}, ${dateShort(date)}';
  }

  static String relative(DateTime date, {bool withTime = false}) {
    final delta = now().difference(date);
    if (delta.inSeconds < 60) return 'только что';
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} ${plural(delta.inMinutes, 'минуту', 'минуты', 'минут')} назад';
    }
    if (delta.inHours < 24 && isToday(date)) {
      return '${delta.inHours} ${plural(delta.inHours, 'час', 'часа', 'часов')} назад';
    }
    if (isYesterday(date)) return 'вчера${withTime ? ', ${time(date)}' : ''}';
    if (delta.inDays < 7) {
      return '${delta.inDays} ${plural(delta.inDays, 'день', 'дня', 'дней')} назад';
    }
    return dateWithYear(date);
  }

  static String deadline(DateTime? date, {bool done = false}) {
    if (date == null) return 'Без срока';
    final todayValue = today();
    final dayDiff = daysBetween(todayValue, startOfDay(date));
    final timePart = isMidnight(date) ? '' : ', ${time(date)}';
    if (done) return '${dateShort(date)}$timePart';
    if (dayDiff < 0) {
      final overdueDays = -dayDiff;
      return 'Просрочено на $overdueDays ${plural(overdueDays, 'день', 'дня', 'дней')}';
    }
    if (dayDiff == 0) return 'Сегодня$timePart';
    if (dayDiff == 1) return 'Завтра$timePart';
    if (dayDiff < 7) return '${weekdayShort(date)}$timePart, ${dateShort(date)}';
    return '${dateShort(date)}$timePart';
  }

  static String plural(int n, String one, String few, String many) {
    final abs = n.abs() % 100;
    if (abs >= 11 && abs <= 14) return many;
    switch (abs % 10) {
      case 1:
        return one;
      case 2:
      case 3:
      case 4:
        return few;
      default:
        return many;
    }
  }
}

abstract final class Money {
  static String somoni(num? value, {bool compact = false, bool withSign = false}) {
    if (value == null) return '—';
    if (compact && value.abs() >= 1000000) {
      final formatted = (value / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '$formatted млн с.';
    }
    if (compact && value.abs() >= 1000) {
      final formatted = (value / 1000).toStringAsFixed(value.abs() >= 100000 ? 0 : 1).replaceAll('.', ',');
      return '$formatted тыс. с.';
    }
    final negative = value < 0;
    final whole = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('\u00A0');
      buffer.write(whole[i]);
    }
    final prefix = withSign && value > 0 ? '+' : (negative ? '−' : '');
    return '$prefix$buffer с.';
  }

  static String number(num? value) {
    if (value == null) return '—';
    final whole = value.abs().round().toString();
    final buffer = StringBuffer(value < 0 ? '−' : '');
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('\u00A0');
      buffer.write(whole[i]);
    }
    return buffer.toString();
  }

  static String hours(double? value) {
    if (value == null || value <= 0) return '0 ч';
    if (value < 1) return '${(value * 60).round()} мин';
    final h = value.floor();
    final m = ((value - h) * 60).round();
    return m == 0 ? '$h ч' : '$h ч $m мин';
  }
}

extension DateTimeRu on DateTime {
  String get ruShort => BizDate.dateShort(this);
  String get ruLong => BizDate.dateLong(this);
  String get ruTime => BizDate.time(this);
  String get ruDayLabel => BizDate.dayLabel(this);
}
