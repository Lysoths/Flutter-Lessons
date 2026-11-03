import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// Harcama listesinin yüklenme durumu.
enum ExpensesStatus {
  /// Kayıtlar okunuyor.
  loading,

  /// Kayıtlar hazır.
  ready,
}

/// Harcama ekranının durumu.
final class ExpensesState extends Equatable {
  /// Bir durum oluşturur.
  const ExpensesState({
    this.status = ExpensesStatus.loading,
    this.expenses = const [],
  });

  /// Yüklenme durumu.
  final ExpensesStatus status;

  /// Harcamalar, en yenisi başta.
  final List<Expense> expenses;

  /// Tüm harcamaların toplamı.
  double get total => expenses.fold(0, (sum, e) => sum + e.amount);

  /// [month] ile aynı ay ve yıldaki harcamalar.
  List<Expense> inMonth(DateTime month) => [
    for (final e in expenses)
      if (e.date.year == month.year && e.date.month == month.month) e,
  ];

  /// [month] ayındaki harcamaların toplamı.
  double totalInMonth(DateTime month) =>
      inMonth(month).fold(0, (sum, e) => sum + e.amount);

  /// [month] ayında kategori başına toplam; büyükten küçüğe sıralı.
  List<({ExpenseCategory category, double amount})> categoryTotals(
    DateTime month,
  ) {
    final sums = <ExpenseCategory, double>{};
    for (final e in inMonth(month)) {
      sums[e.category] = (sums[e.category] ?? 0) + e.amount;
    }
    return [
      for (final entry in sums.entries)
        (category: entry.key, amount: entry.value),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Değiştirilmiş bir kopya döndürür.
  ExpensesState copyWith({ExpensesStatus? status, List<Expense>? expenses}) =>
      ExpensesState(
        status: status ?? this.status,
        expenses: expenses ?? this.expenses,
      );

  @override
  List<Object?> get props => [status, expenses];
}
