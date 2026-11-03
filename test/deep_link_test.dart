import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_form_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DERS 4 — auto_route: rotalar ve deep link.
void main() {
  group('AppDeepLinks.sanitize (beyaz liste)', () {
    String clean(String link) => AppDeepLinks.sanitize(Uri.parse(link)).path;

    test('kabul edilen linkler', () {
      expect(clean('harcamatakibim://app/'), '/');
      expect(clean('harcamatakibim://app/kategori/yemek'), '/kategori/yemek');
      expect(clean('/kategori/ULASIM'), '/kategori/ulasim');
      expect(clean('/yeni'), '/yeni');
    });

    test('tanınmayan her link ana sayfaya düşer', () {
      for (final link in [
        '/kategori/food',
        '/kategori/olmayan',
        '/kategori',
        '/kategori/yemek/fazla',
        '/harcama',
        '/harcama/810c3de2-12f3-4e26-9e7c-70e18723de58',
        '/ayarlar/sifirla',
        '/../../etc/passwd',
        '/yeni/1000',
      ]) {
        expect(clean(link), '/', reason: link);
      }
    });

    test('sorgu parametreleri atılır', () {
      final uri = AppDeepLinks.sanitize(Uri.parse('/yeni?tutar=99999'));
      expect(uri.path, '/yeni');
      expect(uri.query, isEmpty);
    });

    test('kategori slug karşılıkları', () {
      expect(ExpenseCategory.food.slug, 'yemek');
      expect(ExpenseCategory.bills.slug, 'fatura');
    });
  });

  group('uygulamada auto_route', () {
    setUp(() async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
    }

    Future<void> openLink(WidgetTester tester, String path) async {
      await tester.binding.handlePushRoute(path);
      await tester.pumpAndSettle();
    }

    ExpensesCubit expenses(WidgetTester tester) =>
        BlocProvider.of<ExpensesCubit>(
          tester.element(find.byType(ExpensesView, skipOffstage: false)),
        );

    testWidgets('kategori kısayolu tipli rota ile sayfayı açar', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('categoryShortcut_bills')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryExpensesView), findsOneWidget);
      expect(find.text('Fatura'), findsWidgets);

      await tester.tap(find.byKey(const Key('categoryView_back')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryExpensesView), findsNothing);
    });

    testWidgets('sistem geri tuşu kategori sayfasını kapatır', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('categoryShortcut_food')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CategoryExpensesView), findsNothing);
      expect(find.byType(ExpensesView), findsOneWidget);
    });

    testWidgets('uygulama açıkken kategori linki', (tester) async {
      await pump(tester);
      await openLink(tester, '/kategori/eglence');
      expect(find.byType(CategoryExpensesView), findsOneWidget);
      expect(find.text('Eğlence'), findsWidgets);
    });

    testWidgets('yeni linki formu açar, kaydetmez; formdan kayıt olur', (
      tester,
    ) async {
      await pump(tester);
      await openLink(tester, '/yeni?tutar=500');
      expect(find.byType(ExpenseFormSheet), findsOneWidget);
      expect(find.text('500'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('expenses'), isNull);

      await tester.enterText(find.byKey(const Key('expenseForm_amount')), '12');
      await tester.tap(find.byKey(const Key('expenseForm_save')));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseFormSheet), findsNothing);
      expect(expenses(tester).state.total, 12);
    });

    testWidgets('form açıkken ikinci yeni linki ikinci form açmaz', (
      tester,
    ) async {
      await pump(tester);
      await openLink(tester, '/yeni');
      await tester.enterText(find.byKey(const Key('expenseForm_amount')), '42');
      await openLink(tester, '/yeni');
      expect(find.byType(ExpenseFormSheet), findsOneWidget);
    });

    testWidgets('bilinmeyen ve ID içeren link ana sayfayı açar', (
      tester,
    ) async {
      await pump(tester);
      await openLink(tester, '/kategori/yemek');
      await openLink(tester, '/harcama/123');
      expect(find.byType(CategoryExpensesView), findsNothing);
      expect(find.byType(ExpenseDetailView), findsNothing);
      expect(find.byType(ExpensesView), findsOneWidget);
    });

    testWidgets('uygulama kapalıyken gelen link (soğuk açılış)', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/kategori/fatura';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await pump(tester);
      expect(find.byType(CategoryExpensesView), findsOneWidget);

      // Ana sayfa da yığında: geri dönünce o görünür.
      await tester.tap(find.byKey(const Key('categoryView_back')));
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesView), findsOneWidget);
    });

    testWidgets('soğuk açılışta yeni linki formu açar', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/yeni';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await pump(tester);
      expect(find.byType(ExpenseFormSheet), findsOneWidget);
    });
  });
}
