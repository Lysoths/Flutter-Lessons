import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/expense_grouping.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(String id, double amount, DateTime date) =>
    Expense(id: id, amount: amount, category: ExpenseCategory.food, date: date);

// 5 Kasım 2026 perşembe; o haftanın pazartesisi 2 Kasım.
final _now = DateTime(2026, 11, 5, 14);

final _data = [
  _e('a', 100, DateTime(2026, 11, 5, 9)),
  _e('b', 50, DateTime(2026, 11, 2, 9)),
  _e('c', 30, DateTime(2026, 11, 1, 20)), // pazar: önceki hafta, 1 Kasım
  _e('d', 200, DateTime(2026, 10, 31, 12)), // aynı hafta, Ekim'de
  _e('e', 70, DateTime(2026, 10, 10, 12)),
];

void main() {
  group('gruplama', () {
    test('ay → hafta → gün, yeniden eskiye; hafta ay sınırında kesilir', () {
      final g = groupByMonthAndWeek(_data);
      expect(g.map((m) => m.month), [DateTime(2026, 11), DateTime(2026, 10)]);

      final nov = g.first;
      expect(nov.total, 180);
      expect(nov.count, 3);
      expect(nov.weeks.map((w) => w.weekStart), [
        DateTime(2026, 11, 2),
        DateTime(2026, 10, 26),
      ]);
      // 26 Ekim haftasının Kasım parçası yalnız 1 Kasım.
      expect(nov.weeks.last.from, DateTime(2026, 11));
      expect(nov.weeks.last.to, DateTime(2026, 11));
      expect(weekRangeLabel(nov.weeks.last), '1 Kasım');
      expect(weekRangeLabel(nov.weeks.first), '2–8 Kasım');
      expect(nov.weeks.first.days.map((d) => d.day), [
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 2),
      ]);

      final oct = g.last;
      expect(oct.weeks.first.to, DateTime(2026, 10, 31));
      expect(weekRangeLabel(oct.weeks.first), '26–31 Ekim');
      expect(oct.total, 270);
    });

    test('pazartesi bulma', () {
      expect(mondayOf(DateTime(2026, 11, 8, 23)), DateTime(2026, 11, 2));
      expect(mondayOf(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
      expect(mondayOf(DateTime(2026, 3)), DateTime(2026, 2, 23));
    });

    test('açılışta bu ay ve bu hafta; yoksa en yenileri', () {
      final g = groupByMonthAndWeek(_data);
      expect(defaultExpanded(g, _now), (
        month: DateTime(2026, 11),
        week: DateTime(2026, 11, 2),
      ));
      expect(defaultExpanded(g, DateTime(2027, 1, 10)), (
        month: DateTime(2026, 11),
        week: DateTime(2026, 11, 2),
      ));
      expect(defaultExpanded(const [], _now), (month: null, week: null));
    });
  });

  testWidgets('yalnız bu hafta açık; ay ve haftaya dokununca açılır', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExpenseTimeline(
              expenses: _data,
              now: _now,
              onTap: (e) => tapped.add(e.id),
              onDelete: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bu ay · Kasım'), findsOneWidget);
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('Bu hafta'), findsOneWidget);
    // Bu haftanın harcamaları görünür, ötekiler kapalı.
    expect(find.byKey(const Key('expenseTile_a')), findsOneWidget);
    expect(find.byKey(const Key('expenseTile_c')), findsNothing);
    expect(find.byKey(const Key('expenseTile_d')), findsNothing);
    // Ekim, Kasım'a göre: 270 → 180, %33 düşüş.
    expect(find.text('%33'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expenseTile_a')));
    expect(tapped, ['a']);

    await tester.tap(find.byKey(const Key('expenses_week_toggle_2026_10_26')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenseTile_c')), findsOneWidget);

    await tester.tap(find.byKey(const Key('expenses_month_toggle_2026_10_1')));
    await tester.pumpAndSettle();
    // Ay açıldı ama haftaları kapalı.
    expect(find.text('26–31 Ekim'), findsOneWidget);
    expect(find.byKey(const Key('expenseTile_d')), findsNothing);

    // Bu ayı kapatınca haftaları da gizlenir.
    await tester.tap(find.byKey(const Key('expenses_month_toggle_2026_11_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenseTile_a')), findsNothing);
  });
}
