import 'package:flutter_ders/app/models/expense.dart';

/// Harcamaların nerede saklandığını ekranlardan gizler.
///
/// Şimdilik [LocalExpenseRepository] telefon hafızasını kullanır. Google
/// Sheets eklendiğinde yeni bir sınıf yazıp `injection.dart`'ta onu
/// kaydetmek yeterli; ekranlar ve cubit'ler değişmez.
abstract interface class ExpenseRepository {
  /// Tüm harcamaları döndürür.
  Future<List<Expense>> getAll();

  /// Listenin tamamını kaydeder.
  Future<void> saveAll(List<Expense> expenses);
}
