import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DERS 2 — Navigation 2.0: ekranlar durumdan kurulur.
void main() {
  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  Future<void> pumpWithExpenses(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HarcamaApp());
    await tester.pumpAndSettle();
    final cubit = BlocProvider.of<ExpensesCubit>(
      tester.element(find.byType(ExpensesView)),
    );
    await cubit.add(
      amount: 100,
      category: ExpenseCategory.food,
      note: 'market',
    );
    await cubit.add(
      amount: 40,
      category: ExpenseCategory.transport,
      note: 'otobüs',
    );
    await tester.pumpAndSettle();
  }

  // Kategori sayfası açıkken ana sayfa arkada (offstage) kalır.
  NavigationCubit nav(WidgetTester tester) => BlocProvider.of<NavigationCubit>(
    tester.element(find.byType(ExpensesView, skipOffstage: false)),
  );

  testWidgets('kategori satırı durumu değiştirir, sayfa eklenir', (
    tester,
  ) async {
    await pumpWithExpenses(tester);
    await tester.tap(find.byKey(const Key('categoryBreakdown_food')));
    await tester.pumpAndSettle();

    expect(
      nav(tester).state,
      const NavigationState(category: ExpenseCategory.food),
    );
    expect(find.byType(CategoryExpensesView), findsOneWidget);
    // Yalnızca o kategorinin harcamaları listelenir.
    expect(find.text('market'), findsOneWidget);
    expect(find.text('otobüs'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('categoryView_monthTotal')))
          .data,
      '100,00 ₺',
    );
  });

  testWidgets('geri düğmesi pop değil durum değiştirir', (tester) async {
    await pumpWithExpenses(tester);
    await tester.tap(find.byKey(const Key('categoryBreakdown_transport')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('categoryView_back')));
    await tester.pumpAndSettle();
    expect(nav(tester).state, const NavigationState());
    expect(find.byType(CategoryExpensesView), findsNothing);
  });

  testWidgets('sistem geri tuşu sayfayı kaldırır, durum eşitlenir', (
    tester,
  ) async {
    await pumpWithExpenses(tester);
    await tester.tap(find.byKey(const Key('categoryBreakdown_food')));
    await tester.pumpAndSettle();

    // Android geri tuşu.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(nav(tester).state, const NavigationState());
    expect(find.byType(CategoryExpensesView), findsNothing);
  });

  testWidgets('durum kod ile değişince ekran da değişir', (tester) async {
    await pumpWithExpenses(tester);
    nav(tester).openCategory(ExpenseCategory.transport);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryExpensesView), findsOneWidget);
    expect(find.text('otobüs'), findsOneWidget);

    nav(tester).backToHome();
    await tester.pumpAndSettle();
    expect(find.byType(CategoryExpensesView), findsNothing);
  });
}
