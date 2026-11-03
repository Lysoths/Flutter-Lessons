import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_expense_detail/expense_detail_view.dart';
import 'package:flutter_ders/app/views/view_expenses/widgets/category_breakdown_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// Gerçek telefona yakın bir ekran boyutu (S25 Ultra: 384x832 dp).
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);
  }

  /// Ana listeyi [text] görünene kadar kaydırır (liste öğeleri ekran
  /// dışındayken oluşturulmaz).
  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTile(WidgetTester tester, String text) async {
    await reveal(tester, text);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  /// Ana listeyi en üste kaydırıp toplam tutarı okur.
  Future<String> total(WidgetTester tester) async {
    final key = find.byKey(const Key('expensesView_total'));
    if (key.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        key,
        -300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
    }
    return tester.widget<Text>(key).data!;
  }

  Future<void> addExpense(
    WidgetTester tester,
    String amount, {
    String category = 'Ulaşım',
    String note = 'otobüs',
  }) async {
    await tester.tap(find.byKey(const Key('expensesView_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseForm_amount')), amount);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(category),
      ),
    );
    await tester.enterText(find.byKey(const Key('expenseForm_note')), note);
    await tester.tap(find.byKey(const Key('expenseForm_save')));
    await tester.pumpAndSettle();
  }

  testWidgets('boş ekran, geçersiz tutar ve ekleme', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await reveal(tester, 'Henüz harcama yok');
    expect(find.text('Henüz harcama yok'), findsOneWidget);
    expect(await total(tester), '0,00 ₺');
    expect(find.byType(CategoryBreakdownWidget), findsNothing);

    await tester.tap(find.byKey(const Key('expensesView_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseForm_save')));
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir tutar girin'), findsOneWidget);
    expect(find.byKey(const Key('expenseForm_delete')), findsNothing);
    Navigator.of(tester.element(find.byType(Form))).pop();
    await tester.pumpAndSettle();

    await addExpense(tester, '45,5');
    await reveal(tester, 'otobüs');
    expect(find.text('otobüs'), findsOneWidget);
    expect(find.text('BUGÜN'), findsOneWidget);
    expect(await total(tester), '45,50 ₺');
    await reveal(tester, 'Kategoriler');
    expect(find.byType(CategoryBreakdownWidget), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('expenses'), contains('otobüs'));
  });

  // DERS 4 — auto_route: liste → (router.push) detay → (maybePop + sonuç) liste.
  testWidgets('karta dokununca detay açılır, geri tuşu değişiklik yapmaz', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await addExpense(tester, '45,5');

    await tapTile(tester, 'otobüs');
    expect(find.byType(ExpenseDetailView), findsOneWidget);
    expect(find.text('Harcama ayrıntısı'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('expenseDetail_amount'))).data,
      '45,50 ₺',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailView), findsNothing);
    expect(await total(tester), '45,50 ₺');
    await reveal(tester, 'otobüs');
    expect(find.text('otobüs'), findsOneWidget);
  });

  testWidgets('detaydan düzenleme sonucu listeye döner', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await addExpense(tester, '45,5');

    await tapTile(tester, 'otobüs');
    await tester.tap(find.byKey(const Key('expenseDetail_edit')));
    await tester.pumpAndSettle();
    expect(find.text('Harcamayı düzenle'), findsOneWidget);
    expect(find.text('45,50'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('expenseForm_amount')), '60');
    await tester.enterText(find.byKey(const Key('expenseForm_note')), 'taksi');
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Yemek'),
      ),
    );
    await tester.tap(find.byKey(const Key('expenseForm_save')));
    await tester.pumpAndSettle();

    // Form ve detay ekranı kapandı, liste güncellendi.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ExpenseDetailView), findsNothing);
    expect(await total(tester), '60,00 ₺');
    await reveal(tester, 'taksi');
    expect(find.text('taksi'), findsOneWidget);
    expect(find.text('otobüs'), findsNothing);
  });

  testWidgets('detaydan silme ve geri alma', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await addExpense(tester, '20');

    await tapTile(tester, 'otobüs');
    await tester.tap(find.byKey(const Key('expenseDetail_delete')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailView), findsNothing);
    expect(await total(tester), '0,00 ₺');
    expect(find.text('Ulaşım harcaması silindi'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(await total(tester), '20,00 ₺');
  });

  testWidgets('detaydaki düzenleme formundan silme', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await addExpense(tester, '20');

    await tapTile(tester, 'otobüs');
    await tester.tap(find.byKey(const Key('expenseDetail_edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseForm_delete')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailView), findsNothing);
    expect(await total(tester), '0,00 ₺');
  });

  testWidgets('kaydırarak silme', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await addExpense(tester, '20');

    await reveal(tester, 'otobüs');
    await tester.drag(find.text('otobüs'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('otobüs'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('expenses'), '[]');
  });
}
