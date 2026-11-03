import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hafızada çalışan sahte depo.
class _MemoryRepository implements ExpenseRepository {
  _MemoryRepository([List<Expense>? initial]) : saved = [...?initial];

  List<Expense> saved;

  @override
  Future<List<Expense>> getAll() async => [...saved];

  @override
  Future<void> saveAll(List<Expense> expenses) async => saved = [...expenses];
}

void main() {
  final older = Expense(
    id: 'a',
    amount: 50,
    category: ExpenseCategory.food,
    date: DateTime(2026, 1, 5),
  );
  final newer = Expense(
    id: 'b',
    amount: 20,
    category: ExpenseCategory.transport,
    date: DateTime(2026, 2, 5),
  );

  blocTest<ExpensesCubit, ExpensesState>(
    'load kayıtları en yenisi başta olacak şekilde getirir',
    build: () => ExpensesCubit(repository: _MemoryRepository([older, newer])),
    act: (c) => c.load(),
    expect: () => [
      ExpensesState(status: ExpensesStatus.ready, expenses: [newer, older]),
    ],
    verify: (c) => expect(c.state.total, 70),
  );

  test('add ve remove listeyi günceller ve kaydeder', () async {
    final repo = _MemoryRepository();
    final cubit = ExpensesCubit(repository: repo);
    await cubit.load();

    await cubit.add(
      amount: 12.5,
      category: ExpenseCategory.fun,
      note: ' film ',
    );
    expect(cubit.state.expenses.single.amount, 12.5);
    expect(cubit.state.expenses.single.note, 'film');
    expect(repo.saved, cubit.state.expenses);

    final added = cubit.state.expenses.single;
    await cubit.edit(added.copyWith(amount: 30, note: 'konser'));
    expect(cubit.state.expenses.single.id, added.id);
    expect(cubit.state.expenses.single.amount, 30);
    expect(repo.saved.single.note, 'konser');

    final removed = await cubit.remove(added.id);
    expect(removed?.amount, 30);
    expect(cubit.state.expenses, isEmpty);
    expect(repo.saved, isEmpty);
    expect(await cubit.remove('yok'), isNull);

    await cubit.restore(removed!);
    expect(repo.saved, [removed]);
  });
}
