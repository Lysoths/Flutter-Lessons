import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_state.dart';
import 'package:uuid/uuid.dart';

/// Harcama ekranının view model'i: listeyi okur, ekler, düzenler, siler
/// ve kaydeder.
class ExpensesCubit extends BaseViewModelCubit<ExpensesState> {
  /// [repository] üzerinden çalışan bir cubit oluşturur.
  ExpensesCubit({required this.repository}) : super(const ExpensesState());

  /// Harcamaların saklandığı yer.
  final ExpenseRepository repository;
  static const _uuid = Uuid();

  /// Kayıtlı harcamaları okur.
  Future<void> load() async {
    final expenses = await repository.getAll();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    stateChanger(
      ExpensesState(status: ExpensesStatus.ready, expenses: expenses),
    );
  }

  /// Yeni bir harcama ekler ve kaydeder.
  Future<void> add({
    required double amount,
    required ExpenseCategory category,
    String note = '',
    DateTime? date,
  }) => restore(
    Expense(
      id: _uuid.v4(),
      amount: amount,
      category: category,
      date: date ?? DateTime.now(),
      note: note.trim(),
    ),
  );

  /// Var olan bir harcamayı [updated] ile değiştirir ([Expense.id] aynı).
  Future<void> edit(Expense updated) =>
      _save([for (final e in state.expenses) e.id == updated.id ? updated : e]);

  /// [id] kimlikli harcamayı siler ve silineni döndürür (geri almak için).
  Future<Expense?> remove(String id) async {
    final index = state.expenses.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final removed = state.expenses[index];
    await _save([...state.expenses]..removeAt(index));
    return removed;
  }

  /// Silinen bir harcamayı listeye geri koyar.
  Future<void> restore(Expense expense) => _save([expense, ...state.expenses]);

  /// Listeyi tarihe göre sıralar, yayar ve kaydeder.
  Future<void> _save(List<Expense> next) async {
    next.sort((a, b) => b.date.compareTo(a.date));
    stateChanger(state.copyWith(expenses: next));
    await repository.saveAll(next);
  }
}
