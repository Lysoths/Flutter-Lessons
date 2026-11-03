import 'package:flutter/widgets.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/models/expense.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 3 — Deep link
//
// Telefon "harcamatakibim://app/kategori/yemek" linkini uygulamaya iletir.
// Flutter bu linkin yolunu ("/kategori/yemek") Router'a verir; bu parser
// yolu Ders 2'deki NavigationState'e çevirir, RouterDelegate de ekranları
// o duruma göre kurar.
//
// Güvenlik — yalnızca BEYAZ LİSTE kabul edilir:
//   /                    → ana sayfa
//   /kategori/<ad>       → kategori sayfası (ad listede olmalı)
//   /yeni                → yeni harcama formu (yalnızca açar, kaydetmez)
//   başka her şey        → ana sayfa (hata vermez, bilgi sızdırmaz)
// Linkte kimlik (ID) ya da tutar kabul edilmez; sorgu (?a=b) yok sayılır.
// ─────────────────────────────────────────────────────────────────────────

/// Link yolunda kullanılan kategori adları. Enum adı değil, Türkçe ve
/// sabit adlar kullanılır; böylece kod içindeki adlar dışarı açılmaz.
const Map<String, ExpenseCategory> kCategorySlugs = {
  'yemek': ExpenseCategory.food,
  'ulasim': ExpenseCategory.transport,
  'fatura': ExpenseCategory.bills,
  'eglence': ExpenseCategory.fun,
  'diger': ExpenseCategory.other,
};

/// Link yolu ↔ [NavigationState] çevirmeni.
class AppRouteParser extends RouteInformationParser<NavigationState> {
  /// Parser oluşturur.
  const AppRouteParser();

  /// Bir yolu güvenli şekilde duruma çevirir; tanınmayan her yol ana sayfa.
  static NavigationState parse(Uri uri) {
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s.toLowerCase(),
    ];
    if (segments.length == 1 && segments.first == 'yeni') {
      return const NavigationState(newExpenseRequested: true);
    }
    if (segments.length == 2 && segments.first == 'kategori') {
      final category = kCategorySlugs[segments[1]];
      if (category != null) return NavigationState(category: category);
    }
    return const NavigationState();
  }

  /// Bir durumun yolunu üretir (tersi).
  static Uri location(NavigationState state) {
    final category = state.category;
    if (category != null) {
      final slug = kCategorySlugs.entries
          .firstWhere((e) => e.value == category)
          .key;
      return Uri(path: '/kategori/$slug');
    }
    return Uri(path: '/');
  }

  @override
  Future<NavigationState> parseRouteInformation(
    RouteInformation routeInformation,
  ) async => parse(routeInformation.uri);

  @override
  RouteInformation restoreRouteInformation(NavigationState configuration) =>
      RouteInformation(uri: location(configuration));
}
