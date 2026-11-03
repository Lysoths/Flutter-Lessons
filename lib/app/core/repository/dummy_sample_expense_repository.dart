import 'dart:math';

import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 7 — Bellekte üretilen [total] adet sahte harcama.
///
/// Sabit bir tohumla ([seed]) üretildiği için her açılışta aynı liste
/// gelir. Gerçek bir sunucu gibi davranması için her sayfa [delay] kadar
/// bekletilir. Hiçbir şey telefona kaydedilmez; gerçek harcamalarınıza
/// dokunmaz.
class DummySampleExpenseRepository implements SampleExpenseRepository {
  /// Sahte depoyu oluşturur.
  DummySampleExpenseRepository({
    this.total = 500,
    this.delay = const Duration(milliseconds: 600),
    int seed = 7,
  }) : _all = _generate(total, seed);

  /// Toplam kayıt sayısı.
  final int total;

  /// Her sayfanın "ağdan gelme" süresi.
  final Duration delay;

  final List<Expense> _all;

  static const _notes = {
    ExpenseCategory.food: [
      'Market alışverişi',
      'Öğle yemeği',
      'Kahve',
      'Fırın',
    ],
    ExpenseCategory.transport: ['Akbil', 'Taksi', 'Benzin', 'Otopark'],
    ExpenseCategory.bills: ['Elektrik', 'Su', 'İnternet', 'Telefon'],
    ExpenseCategory.fun: ['Sinema', 'Konser', 'Kitap', 'Oyun'],
    ExpenseCategory.other: ['Kırtasiye', 'Hediye', 'Eczane', 'Kargo'],
  };

  static List<Expense> _generate(int total, int seed) {
    final random = Random(seed);
    final start = DateTime(2026, 11, 3, 20);
    return List.generate(total, (i) {
      final category =
          ExpenseCategory.values[random.nextInt(ExpenseCategory.values.length)];
      final notes = _notes[category]!;
      return Expense(
        id: 'ornek_${i + 1}',
        amount: (random.nextInt(195000) + 500) / 100,
        category: category,
        // En yenisi başta: her kayıt bir öncekinden 7 saat eski.
        date: start.subtract(Duration(hours: i * 7)),
        note: notes[random.nextInt(notes.length)],
      );
    });
  }

  @override
  Future<ExpensePage> fetchPage({
    required int page,
    required int pageSize,
  }) async {
    if (page < 1 || pageSize < 1) {
      throw ArgumentError('page ve pageSize 1 veya daha büyük olmalı');
    }
    await Future<void>.delayed(delay);
    final from = (page - 1) * pageSize;
    if (from >= total) {
      return (items: <Expense>[], hasMore: false, total: total);
    }
    final to = min(from + pageSize, total);
    return (items: _all.sublist(from, to), hasMore: to < total, total: total);
  }
}
