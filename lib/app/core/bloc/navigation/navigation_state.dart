import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 2 — Navigation 2.0: uygulamanın "şu an hangi ekranlar açık?"
/// bilgisi. Ekran yığını bu durumdan kurulur (bkz. `AppRouterDelegate`).
final class NavigationState extends Equatable {
  /// Bir gezinme durumu oluşturur.
  const NavigationState({this.category, this.newExpenseRequested = false});

  /// Açık kategori ekranı; `null` ise yalnızca ana sayfa açıktır.
  final ExpenseCategory? category;

  /// DERS 3 — Deep link: "yeni harcama" formu açılmak isteniyor mu?
  /// Ana sayfa formu açınca bu bayrak geri indirilir.
  final bool newExpenseRequested;

  /// Kategori ekranı açık mı?
  bool get isCategoryOpen => category != null;

  @override
  List<Object?> get props => [category, newExpenseRequested];
}
