import 'package:flutter_ders/app/core/repository/local_expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('kaydedilen harcamalar geri okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalExpenseRepository(await SharedPreferences.getInstance());
    expect(await repo.getAll(), isEmpty);

    final expense = Expense(
      id: '1',
      amount: 99.9,
      category: ExpenseCategory.bills,
      date: DateTime(2026, 11, 2, 20, 30),
      note: 'elektrik',
    );
    await repo.saveAll([expense]);

    final again = LocalExpenseRepository(await SharedPreferences.getInstance());
    expect(await again.getAll(), [expense]);
  });
}
