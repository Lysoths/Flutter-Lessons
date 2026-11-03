import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_cubit.dart';
import 'package:flutter_ders/app/core/bloc/navigation/navigation_state.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_route_parser.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_category/category_expenses_view.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/expense_form_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DERS 3 — Deep link.
void main() {
  group('AppRouteParser (beyaz liste)', () {
    NavigationState parse(String link) => AppRouteParser.parse(Uri.parse(link));

    test('kabul edilen linkler', () {
      expect(parse('harcamatakibim://app/'), const NavigationState());
      expect(
        parse('harcamatakibim://app/kategori/yemek'),
        const NavigationState(category: ExpenseCategory.food),
      );
      expect(
        parse('/kategori/ULASIM'),
        const NavigationState(category: ExpenseCategory.transport),
      );
      expect(parse('/yeni'), const NavigationState(newExpenseRequested: true));
    });

    test('tanınmayan her link ana sayfaya düşer', () {
      for (final link in [
        '/kategori/food', // enum adı değil, Türkçe ad kabul edilir
        '/kategori/olmayan',
        '/kategori',
        '/kategori/yemek/fazla',
        '/harcama/810c3de2-12f3-4e26-9e7c-70e18723de58', // ID kabul edilmez
        '/ayarlar/sifirla',
        '/../../etc/passwd',
        '/yeni/1000',
      ]) {
        expect(parse(link), const NavigationState(), reason: link);
      }
    });

    test('sorgu parametreleri (tutar vb.) yok sayılır', () {
      expect(
        parse('/yeni?tutar=99999&not=x'),
        const NavigationState(newExpenseRequested: true),
      );
    });

    test('durum → yol (tersi)', () {
      expect(AppRouteParser.location(const NavigationState()).path, '/');
      expect(
        AppRouteParser.location(
          const NavigationState(category: ExpenseCategory.bills),
        ).path,
        '/kategori/fatura',
      );
    });
  });

  group('uygulamada deep link', () {
    setUp(() async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
    });

    NavigationCubit nav(WidgetTester tester) =>
        BlocProvider.of<NavigationCubit>(
          tester.element(find.byType(ExpensesView, skipOffstage: false)),
        );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const HarcamaApp());
      await tester.pumpAndSettle();
    }

    Future<void> openLink(WidgetTester tester, String path) async {
      await tester.binding.handlePushRoute(path);
      await tester.pumpAndSettle();
    }

    testWidgets('uygulama açıkken kategori linki', (tester) async {
      await pump(tester);
      await openLink(tester, '/kategori/eglence');
      expect(find.byType(CategoryExpensesView), findsOneWidget);
      expect(
        nav(tester).state,
        const NavigationState(category: ExpenseCategory.fun),
      );
    });

    testWidgets('yeni linki formu açar ama kaydetmez', (tester) async {
      await pump(tester);
      await openLink(tester, '/kategori/yemek');
      await openLink(tester, '/yeni?tutar=500');

      // Kategori sayfası kapandı, ana sayfada form açık ve boş.
      expect(find.byType(CategoryExpensesView), findsNothing);
      expect(find.byType(ExpenseFormSheet), findsOneWidget);
      expect(find.text('500'), findsNothing);
      expect(nav(tester).state.newExpenseRequested, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('expenses'), isNull);
    });

    testWidgets('form açıkken gelen ikinci yeni linki ikinci form açmaz', (
      tester,
    ) async {
      await pump(tester);
      await openLink(tester, '/yeni');
      await tester.enterText(find.byKey(const Key('expenseForm_amount')), '42');
      await openLink(tester, '/yeni');
      expect(find.byType(ExpenseFormSheet), findsOneWidget);
      // Kullanıcının yazdığı kaybolmaz.
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('detay ekranı açıkken yeni linki üstüne form açmaz', (
      tester,
    ) async {
      await pump(tester);
      final expenses = BlocProvider.of<ExpensesCubit>(
        tester.element(find.byType(ExpensesView)),
      );
      await expenses.add(amount: 5, category: ExpenseCategory.food, note: 'su');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('su'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('su'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseDetailView), findsOneWidget);

      await openLink(tester, '/yeni');
      expect(find.byType(ExpenseFormSheet), findsNothing);
      expect(find.byType(ExpenseDetailView), findsOneWidget);
    });

    testWidgets('bilinmeyen link ana sayfayı açar', (tester) async {
      await pump(tester);
      await openLink(tester, '/kategori/yemek');
      await openLink(tester, '/harcama/123');
      expect(find.byType(CategoryExpensesView), findsNothing);
      expect(nav(tester).state, const NavigationState());
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
      expect(find.text('Fatura'), findsWidgets);
    });

    testWidgets('soğuk açılışta yeni linki formu açar', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/yeni';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await pump(tester);
      expect(find.byType(ExpenseFormSheet), findsOneWidget);
    });

    testWidgets('kategori kısayolu da aynı durumu kullanır', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('categoryShortcut_bills')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryExpensesView), findsOneWidget);
      expect(
        nav(tester).state,
        const NavigationState(category: ExpenseCategory.bills),
      );
    });
  });
}
