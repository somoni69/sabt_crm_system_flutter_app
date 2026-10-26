import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/utils/date_utils.dart';

void main() {
  test('business date key is stable for Dushanbe wall clock', () {
    expect(BizDate.key(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('deadline label counts full days in business timezone', () {
    final today = BizDate.today();
    expect(BizDate.deadline(today), startsWith('Сегодня'));
    expect(
      BizDate.deadline(today.subtract(const Duration(days: 2))),
      startsWith('Просрочено'),
    );
  });

  test('money formats somoni with a narrow space', () {
    expect(Money.somoni(120000), '120\u00A0000 с.');
  });
}
