import 'date_utils.dart';

class DateRangeKey {
  const DateRangeKey(this.from, this.to);

  final DateTime from;
  final DateTime to;

  factory DateRangeKey.month(DateTime month) => DateRangeKey(
        BizDate.monthStart(month),
        BizDate.monthEnd(month),
      );

  factory DateRangeKey.week(DateTime day) {
    final start = BizDate.weekStart(day);
    return DateRangeKey(start, start.add(const Duration(days: 6)));
  }

  String get fromKey => BizDate.key(from);
  String get toKey => BizDate.key(to);

  bool contains(DateTime date) {
    final day = BizDate.startOfDay(date);
    return !day.isBefore(BizDate.startOfDay(from)) &&
        !day.isAfter(BizDate.startOfDay(to));
  }

  @override
  bool operator ==(Object other) =>
      other is DateRangeKey && other.fromKey == fromKey && other.toKey == toKey;

  @override
  int get hashCode => Object.hash(fromKey, toKey);
}

class MonthKey {
  const MonthKey(this.year, this.month);

  factory MonthKey.of(DateTime date) => MonthKey(date.year, date.month);

  factory MonthKey.current() {
    final now = BizDate.today();
    return MonthKey(now.year, now.month);
  }

  final int year;
  final int month;

  DateTime get start => DateTime(year, month, 1);
  DateTime get end => DateTime(year, month + 1, 0);
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  MonthKey add(int months) {
    final date = DateTime(year, month + months, 1);
    return MonthKey(date.year, date.month);
  }

  DateRangeKey get range => DateRangeKey(start, end);

  bool get isCurrent {
    final now = BizDate.today();
    return now.year == year && now.month == month;
  }

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}
