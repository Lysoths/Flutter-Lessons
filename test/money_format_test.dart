import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMoney', () {
    expect(formatMoney(0), '0,00 ₺');
    expect(formatMoney(1234.5), '1.234,50 ₺');
    expect(formatMoney(1000000), '1.000.000,00 ₺');
    expect(editableMoney(12.5), '12,50');
  });

  test('parseMoney', () {
    expect(parseMoney('12,5'), 12.5);
    expect(parseMoney(' 7.25 '), 7.25);
    expect(parseMoney('abc'), isNull);
    expect(parseMoney('0'), isNull);
    expect(parseMoney('-5'), isNull);
  });

  test('formatDayLabel ve formatMonth', () {
    final now = DateTime(2026, 11, 2, 21);
    expect(formatDayLabel(DateTime(2026, 11, 2, 8), now: now), 'Bugün');
    expect(formatDayLabel(DateTime(2026, 11, 1, 23), now: now), 'Dün');
    expect(formatDayLabel(DateTime(2026, 10, 30), now: now), '30 Ekim 2026');
    expect(formatMonth(now), 'Kasım 2026');
  });
}
