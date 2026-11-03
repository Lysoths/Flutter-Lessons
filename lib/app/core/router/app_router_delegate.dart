import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 2 — Navigation 2.0 (declarative / bildirimsel yöntem)
//
// "Şu ekranı aç" (push) yerine DURUM tanımlanır:
//
//   NavigationState(category: null)   → [Ana sayfa]
//   NavigationState(category: yemek)  → [Ana sayfa, Yemek kategorisi]
//
// RouterDelegate bu durumu okuyup Navigator'a bir sayfa LİSTESİ (pages)
// verir. Durum değişince (NavigationCubit) liste yeniden kurulur ve Flutter
// eklenen/çıkan sayfaları kendisi animasyonla açar/kapatır.
//
// Geri hareketi (sistem geri tuşu, iOS kaydırma) bir sayfayı kaldırırsa
// onDidRemovePage ile durum da güncellenir; durum ve ekran hep aynıdır.
// ─────────────────────────────────────────────────────────────────────────

/// Ekran yığınını [NavigationCubit] durumundan kuran RouterDelegate.
class AppRouterDelegate extends RouterDelegate<NavigationState>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<NavigationState> {
  /// [cubit] durumunu dinleyen bir delegate oluşturur.
  AppRouterDelegate(this.cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  /// Gezinme durumunun kaynağı.
  final NavigationCubit cubit;

  late final StreamSubscription<NavigationState> _subscription;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Şu anki durum (Ders 3'te adres/deep link ile eşlenecek).
  @override
  NavigationState get currentConfiguration => cubit.state;

  /// Dışarıdan yeni bir durum geldiğinde (Ders 3: deep link) uygular.
  @override
  Future<void> setNewRoutePath(NavigationState configuration) async =>
      cubit.restore(configuration);

  @override
  Widget build(BuildContext context) {
    final category = cubit.state.category;
    return Navigator(
      key: navigatorKey,
      // Sayfa listesi doğrudan durumdan türetilir.
      pages: [
        const MaterialPage<void>(
          key: ValueKey('page_home'),
          child: ExpensesView(),
        ),
        if (category != null)
          MaterialPage<void>(
            key: ValueKey('page_category_${category.name}'),
            child: CategoryExpensesView(category: category),
          ),
      ],
      // Sistem geri hareketi bir sayfayı kaldırınca durumu eşitle.
      onDidRemovePage: (page) {
        if (page.key != const ValueKey('page_home')) cubit.backToHome();
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
