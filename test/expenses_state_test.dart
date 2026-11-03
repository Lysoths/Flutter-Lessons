import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense e(String id, double amount, ExpenseCategory c, DateTime d) =>
      Expense(id: id, amount: amount, category: c, date: d);

  final state = ExpensesState(
    status: ExpensesStatus.ready,
    expenses: [
      e('1', 100, ExpenseCategory.food, DateTime(2026, 11, 2)),
      e('2', 50, ExpenseCategory.transport, DateTime(2026, 11, 3)),
      e('3', 30, ExpenseCategory.food, DateTime(2026, 11, 4)),
      e('4', 999, ExpenseCategory.fun, DateTime(2026, 10, 30)),
      e('5', 7, ExpenseCategory.food, DateTime(2025, 11, 5)),
    ],
  );

  test('ay toplamı yalnızca aynı ay ve yılı sayar', () {
    expect(state.totalInMonth(DateTime(2026, 11, 15)), 180);
    expect(state.inMonth(DateTime(2026, 10, 2)).single.id, '4');
    expect(state.total, 1186);
  });

  test('kategori toplamları büyükten küçüğe', () {
    final totals = state.categoryTotals(DateTime(2026, 11));
    expect(totals.map((t) => t.category), [
      ExpenseCategory.food,
      ExpenseCategory.transport,
    ]);
    expect(totals.first.amount, 130);
  });
}
