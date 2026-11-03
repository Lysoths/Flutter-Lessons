import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_ders/app/views/view_new_expense/new_expense_view.dart';

part 'app_router.gr.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 4 — auto_route
//
// Sayfalar @RoutePage() ile işaretlenir; `dart run build_runner build`
// her sayfa için tipli bir rota sınıfı üretir (app_router.gr.dart):
//
//   ExpensesView         → ExpensesRoute()
//   CategoryExpensesView → CategoryExpensesRoute(slug: 'yemek')
//   ExpenseDetailView    → ExpenseDetailRoute(expense: e)
//   NewExpenseView       → NewExpenseRoute()
//
// Uygulama içinde geçişler bu sınıflarla yapılır (yazı/yol yok):
//   context.router.push(ExpenseDetailRoute(expense: e));
//
// Aşağıdaki tablo hangi sayfanın hangi yolda olduğunu söyler; deep
// link'ler bu tabloyla eşlenir (önce AppDeepLinks.transform süzer).
// Bu dosya değişince: dart run build_runner build
// ─────────────────────────────────────────────────────────────────────────

/// Uygulamanın rota tablosu.
@AutoRouterConfig(replaceInRouteName: 'View,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: ExpensesRoute.page, path: '/', initial: true),
    AutoRoute(page: CategoryExpensesRoute.page, path: '/kategori/:slug'),
    // Detay ekranı nesne ister; dışarıdan gelen link buraya ulaşamaz.
    AutoRoute(page: ExpenseDetailRoute.page, path: '/harcama'),
    // Yeni harcama formu alttan açılan pencere (bottom sheet) olarak.
    CustomRoute<void>(
      page: NewExpenseRoute.page,
      path: '/yeni',
      customRouteBuilder: <T>(context, child, page) => ModalBottomSheetRoute<T>(
        settings: page,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => child,
      ),
    ),
  ];
}
