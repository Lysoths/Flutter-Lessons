import 'package:flutter_ders/app/models/expense.dart';

// Ana sayfa listesi: ay → hafta → gün. Haftalar pazartesi başlar ve ayın
// sınırında kesilir (ör. "1–2 Kasım" ayrı bir hafta parçasıdır); böylece
// her harcama tek bir ay kartında, tek bir hafta bölümünde görünür.

/// Bir gündeki harcamalar.
typedef DayGroup = ({DateTime day, List<Expense> items});

/// Bir ayın içindeki bir hafta.
final class WeekGroup {
  /// Oluşturur.
  const WeekGroup({
    required this.weekStart,
    required this.from,
    required this.to,
    required this.days,
  });

  /// Haftanın pazartesisi (ay dışında kalabilir).
  final DateTime weekStart;

  /// Bu ay içindeki ilk gün.
  final DateTime from;

  /// Bu ay içindeki son gün.
  final DateTime to;

  /// Günler (en yenisi başta).
  final List<DayGroup> days;

  /// Toplam.
  double get total =>
      days.fold(0, (s, d) => s + d.items.fold(0, (a, e) => a + e.amount));

  /// Harcama sayısı.
  int get count => days.fold(0, (s, d) => s + d.items.length);
}

/// Bir ay.
final class MonthGroup {
  /// Oluşturur.
  const MonthGroup({required this.month, required this.weeks});

  /// Ayın ilk günü.
  final DateTime month;

  /// Haftalar (en yenisi başta).
  final List<WeekGroup> weeks;

  /// Toplam.
  double get total => weeks.fold(0, (s, w) => s + w.total);

  /// Harcama sayısı.
  int get count => weeks.fold(0, (s, w) => s + w.count);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] gününün haftasının pazartesisi.
DateTime mondayOf(DateTime d) {
  final day = _day(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// Harcamaları ay → hafta → gün olarak gruplar; hepsi yeniden eskiye.
List<MonthGroup> groupByMonthAndWeek(List<Expense> expenses) {
  final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
  final months = <DateTime, Map<DateTime, Map<DateTime, List<Expense>>>>{};
  for (final e in sorted) {
    final month = DateTime(e.date.year, e.date.month);
    final week = mondayOf(e.date);
    final day = _day(e.date);
    (((months[month] ??= {})[week] ??= {})[day] ??= []).add(e);
  }
  return [
    for (final MapEntry(key: month, value: weeks) in months.entries)
      MonthGroup(
        month: month,
        weeks: [
          for (final MapEntry(key: start, value: days) in weeks.entries)
            WeekGroup(
              weekStart: start,
              from: start.isBefore(month) ? month : start,
              to: () {
                final end = DateTime(start.year, start.month, start.day + 6);
                final last = DateTime(month.year, month.month + 1, 0);
                return end.isAfter(last) ? last : end;
              }(),
              days: [
                for (final MapEntry(key: day, value: items) in days.entries)
                  (day: day, items: items),
              ],
            ),
        ],
      ),
  ];
}

/// Açılışta açık duracak ay ve hafta: bu ay / bu hafta varsa onlar, yoksa en
/// yeni ay ve onun en yeni haftası.
({DateTime? month, DateTime? week}) defaultExpanded(
  List<MonthGroup> groups,
  DateTime now,
) {
  if (groups.isEmpty) return (month: null, week: null);
  final thisMonth = DateTime(now.year, now.month);
  final month = groups.firstWhere(
    (g) => g.month == thisMonth,
    orElse: () => groups.first,
  );
  final thisWeek = mondayOf(now);
  final week = month.weeks.firstWhere(
    (w) => w.weekStart == thisWeek,
    orElse: () => month.weeks.first,
  );
  return (month: month.month, week: week.weekStart);
}
