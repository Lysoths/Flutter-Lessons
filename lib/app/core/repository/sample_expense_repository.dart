import 'package:flutter_ders/app/models/expense.dart';

/// Bir sayfalık sonuç: gelen kayıtlar, devamı var mı, toplam kaç kayıt.
typedef ExpensePage = ({List<Expense> items, bool hasMore, int total});

/// DERS 7 — Örnek harcamaları SAYFA SAYFA veren depo.
///
/// Ekran tüm listeyi bir kerede istemez; "1. sayfayı 20'şer ver",
/// "2. sayfayı ver"... diye sorar. Bugün veriler bir JSON dosyasından
/// gelir ([JsonSampleExpenseRepository]); bir gün bir sunucudan gelirse
/// yeni bir sınıf yazıp `injection.dart`'ta onu kaydetmek yeterli.
abstract interface class SampleExpenseRepository {
  /// [page]. sayfayı (1'den başlar) [pageSize] kayıt olarak döndürür.
  Future<ExpensePage> fetchPage({required int page, required int pageSize});
}
