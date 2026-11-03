import 'package:flutter/foundation.dart';
import 'package:flutter_ders/app/models/expense.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 4 — auto_route: deep link beyaz listesi
//
// auto_route gelen linki kendi rota tablosuyla eşler. Eşlemeden ÖNCE
// [AppDeepLinks.transform] çalışır ve linki yalnızca izin verilen
// biçimlerden birine çevirir:
//
//   /kategori/<ad>   → /kategori/<ad>   (ad listede olmalı)
//   /yeni            → /yeni            (form açılır, kayıt yapılmaz)
//   /belgeler        → /belgeler        (yalnızca liste; tek tek belgeler
//                                         dışarıdan açılamaz)
//   başka her şey    → /                (ana sayfa)
//
// Sorgu parametreleri (?tutar=...) her durumda atılır; linkte kimlik
// (ID) kabul edilmez. Harcama detayı dışarıdan hiç açılamaz.
// ─────────────────────────────────────────────────────────────────────────

/// Link yolunda kullanılan sabit Türkçe kategori adları.
const Map<String, ExpenseCategory> kCategorySlugs = {
  'yemek': ExpenseCategory.food,
  'ulasim': ExpenseCategory.transport,
  'fatura': ExpenseCategory.bills,
  'eglence': ExpenseCategory.fun,
  'diger': ExpenseCategory.other,
};

/// Kategorinin link adı.
extension ExpenseCategorySlug on ExpenseCategory {
  /// Örn. `ExpenseCategory.food.slug` → `yemek`.
  String get slug =>
      kCategorySlugs.entries.firstWhere((e) => e.value == this).key;
}

/// Gelen linkleri beyaz listeye göre süzen yardımcılar.
abstract final class AppDeepLinks {
  /// Bir linki güvenli yola çevirir; tanınmayan her şey `/` olur.
  static Uri sanitize(Uri uri) {
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s.toLowerCase(),
    ];
    if (segments.length == 1 && segments.first == 'yeni') {
      return Uri(path: '/yeni');
    }
    if (segments.length == 1 && segments.first == 'belgeler') {
      return Uri(path: '/belgeler');
    }
    if (segments.length == 2 &&
        segments.first == 'kategori' &&
        kCategorySlugs.containsKey(segments[1])) {
      return Uri(path: '/kategori/${segments[1]}');
    }
    return Uri(path: '/');
  }

  /// auto_route'un `deepLinkTransformer` imzası.
  static Future<Uri> transform(Uri uri) => SynchronousFuture(sanitize(uri));
}
