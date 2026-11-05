import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/json_sample_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/views/view_paged_grid/widgets/expense_grid_card.dart';
import 'package:flutter_ders/app/views/view_paged_grid/widgets/expense_grid_card_skeleton.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_ders/app/views/view_paged_list/widgets/expense_tile_skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

/// İstekleri sayan, istenirse hata veren depo.
class _CountingRepository implements SampleExpenseRepository {
  final _inner = JsonSampleExpenseRepository(delay: Duration.zero);
  final requested = <int>[];
  bool fail = false;

  @override
  Future<ExpensePage> fetchPage({required int page, required int pageSize}) {
    requested.add(page);
    if (fail) return Future.error(StateError('ağ yok'));
    return _inner.fetchPage(page: page, pageSize: pageSize);
  }
}

// DERS 7 — Sayfalama + ListView.builder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JSON deposu', () {
    final repo = JsonSampleExpenseRepository(delay: Duration.zero);

    test('500 kayıt 20\'şer 25 sayfadır', () async {
      final first = await repo.fetchPage(page: 1, pageSize: 20);
      expect(first.items, hasLength(20));
      expect(first.items.first.id, 'ornek_1');
      expect(first.hasMore, isTrue);
      expect(first.total, 500);

      final last = await repo.fetchPage(page: 25, pageSize: 20);
      expect(last.items.last.id, 'ornek_500');
      expect(last.hasMore, isFalse);

      final after = await repo.fetchPage(page: 26, pageSize: 20);
      expect(after.items, isEmpty);
      expect(after.hasMore, isFalse);
    });

    test('JSON dosyasındaki 500 kaydın hepsi okunur', () async {
      final all = await repo.fetchPage(page: 1, pageSize: 1000);
      expect(all.items, hasLength(500));
      expect(all.items.map((e) => e.id).toSet(), hasLength(500));
      expect(all.items.every((e) => e.amount > 0), isTrue);
      // En yenisi başta.
      for (var i = 1; i < all.items.length; i++) {
        expect(all.items[i - 1].date.isAfter(all.items[i].date), isTrue);
      }
    });

    test('geçersiz sayfa reddedilir', () {
      expect(() => repo.fetchPage(page: 0, pageSize: 20), throwsArgumentError);
    });

    test('sayfa listesi deep link ile açılamaz', () {
      final clean = AppDeepLinks.sanitize(
        Uri.parse('harcamatakibim://app/ornek-liste'),
      );
      expect(clean.path, '/');
    });
  });

  group('cubit', () {
    blocTest<PagedListCubit, PagedListState>(
      'ilk sayfa, sonra ikinci sayfa listenin sonuna eklenir',
      build: () => PagedListCubit(repository: _CountingRepository()),
      act: (c) async {
        await c.loadFirstPage();
        await c.loadNextPage();
      },
      verify: (c) {
        expect(c.state.status, PagedListStatus.ready);
        expect(c.state.items, hasLength(40));
        expect(c.state.items[20].id, 'ornek_21');
        expect(c.state.page, 2);
      },
    );

    test('aynı anda gelen istekler tek isteğe düşer', () async {
      final repo = _CountingRepository();
      final cubit = PagedListCubit(repository: repo);
      await cubit.loadFirstPage();
      await Future.wait([
        cubit.loadNextPage(),
        cubit.loadNextPage(),
        cubit.loadNextPage(),
      ]);
      expect(repo.requested, [1, 2]);
      expect(cubit.state.items, hasLength(40));
      await cubit.close();
    });

    test('son sayfadan sonra istek atılmaz', () async {
      final repo = _CountingRepository();
      final cubit = PagedListCubit(repository: repo, pageSize: 250);
      await cubit.loadFirstPage();
      await cubit.loadNextPage();
      await cubit.loadNextPage();
      expect(repo.requested, [1, 2]);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.items, hasLength(500));
      await cubit.close();
    });

    test('hata olursa liste korunur, tekrar dene devam eder', () async {
      final repo = _CountingRepository();
      final cubit = PagedListCubit(repository: repo);
      await cubit.loadFirstPage();
      repo.fail = true;
      await cubit.loadNextPage();
      expect(cubit.state.status, PagedListStatus.failure);
      expect(cubit.state.items, hasLength(20));

      repo.fail = false;
      await cubit.retry();
      expect(cubit.state.status, PagedListStatus.ready);
      expect(cubit.state.items, hasLength(40));
      await cubit.close();
    });

    test('yenileme ilk sayfaya döner', () async {
      final cubit = PagedListCubit(repository: _CountingRepository());
      await cubit.loadFirstPage();
      await cubit.loadNextPage();
      await cubit.refresh();
      expect(cubit.state.items, hasLength(20));
      expect(cubit.state.page, 1);
      await cubit.close();
    });
  });

  group('ekranda', () {
    setUp(() async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
      // Testte "ağ" beklemesin. Dosya okuma gerçek bir G/Ç işlemidir ve
      // testWidgets'ın sahte saatinde bitmez; bu yüzden JSON burada,
      // test başlamadan bir kez okunur.
      final repo = JsonSampleExpenseRepository(delay: Duration.zero);
      await repo.fetchPage(page: 1, pageSize: 1);
      getIt
        ..unregister<SampleExpenseRepository>()
        ..registerSingleton<SampleExpenseRepository>(repo);
    });

    String counter(WidgetTester tester) => (tester.widget(
      find.descendant(
        of: find.byKey(const Key('pagedList_counter')),
        matching: find.byType(Text),
      ),
    ) as Text).data!;

    Future<void> settle(WidgetTester tester) async {
      // Yükleniyor göstergesi sürekli döndüğü için pumpAndSettle yerine
      // birkaç kare ilerletilir.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Sayfa başına [delay] bekleten, önceden okunmuş bir depo kurar.
    Future<void> slowRepository(WidgetTester tester, Duration delay) async {
      final repo = JsonSampleExpenseRepository(delay: delay);
      await tester.runAsync(() => repo.fetchPage(page: 1, pageSize: 1));
      getIt
        ..unregister<SampleExpenseRepository>()
        ..registerSingleton<SampleExpenseRepository>(repo);
    }

    /// Ana sayfadaki [cardKey] kartıyla ekranı açıp İskelet sekmesine geçer.
    Future<void> openSkeletonTab(WidgetTester tester, String cardKey) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      await tester.scrollUntilVisible(
        find.byKey(Key(cardKey)),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.byKey(Key(cardKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('pagedTab_skeleton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('liste İskelet sekmesi: önce iskelet, sonra kayıtlar', (
      tester,
    ) async {
      await slowRepository(tester, const Duration(milliseconds: 600));
      await openSkeletonTab(tester, 'lessons_pagedList');

      // Veri gelmeden: dönen gösterge yok, iskelet satırlar var.
      expect(
        find.byKey(const Key('pagedList_initialSkeleton')),
        findsOneWidget,
      );
      expect(find.byType(ExpenseTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('pagedList_initialSkeleton')), findsNothing);
      expect(find.textContaining('#1 ·'), findsOneWidget);

      // Sona kadar kaydır: yol boyunca dönen gösterge hiç çıkmaz.
      final list = find.byKey(const Key('pagedList_list_skeleton'));
      var guard = 0;
      while (find.byKey(const Key('pagedList_end')).evaluate().isEmpty) {
        await tester.drag(list, const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('pagedList_loadingMore')), findsNothing);
        await tester.pump(const Duration(milliseconds: 700));
        expect(guard++, lessThan(200), reason: 'liste sonuna ulaşılamadı');
      }
      expect(counter(tester), '500 / 500 kayıt');
      // Kayıtlar bitince iskelet kalmaz.
      expect(find.byType(ExpenseTileSkeleton), findsNothing);
    });

    testWidgets('ızgara İskelet sekmesi: önce iskelet kartlar', (tester) async {
      await slowRepository(tester, const Duration(milliseconds: 600));
      await openSkeletonTab(tester, 'lessons_pagedGrid');

      expect(
        find.byKey(const Key('pagedGrid_initialSkeleton')),
        findsOneWidget,
      );
      expect(find.byType(ExpenseGridCardSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('gridCard_1')), findsOneWidget);
      expect(counter(tester), '20 / 500 kayıt');
    });

    testWidgets('sekmeler birbirinden bağımsız sayfalanır', (tester) async {
      await slowRepository(tester, Duration.zero);
      await openSkeletonTab(tester, 'lessons_pagedList');
      await settle(tester);
      await tester.drag(
        find.byKey(const Key('pagedList_list_skeleton')),
        const Offset(0, -3000),
      );
      await settle(tester);
      expect(counter(tester), '40 / 500 kayıt');

      await tester.tap(find.byKey(const Key('pagedTab_standard')));
      await settle(tester);
      expect(counter(tester), '20 / 500 kayıt');
    });

    testWidgets('kaydırdıkça sayfalar gelir, 500\'de durur', (tester) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lessons_pagedList')),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('lessons_pagedList')));
      await settle(tester);

      expect(counter(tester), '20 / 500 kayıt');
      expect(find.textContaining('#1 ·'), findsOneWidget);
      // 2. sayfa henüz istenmedi.
      expect(find.textContaining('#21 ·'), findsNothing);

      final list = find.byKey(const Key('pagedList_list_standard'));
      var guard = 0;
      while (find.byKey(const Key('pagedList_end')).evaluate().isEmpty) {
        await tester.drag(list, const Offset(0, -3000));
        await settle(tester);
        expect(guard++, lessThan(200), reason: 'liste sonuna ulaşılamadı');
      }
      expect(counter(tester), '500 / 500 kayıt');
      expect(find.textContaining('#500 ·'), findsOneWidget);
      // Ekranda 500 satırın tamamı değil, yalnızca bir avuç satır vardır.
      expect(
        find.textContaining(RegExp(r'^#\d+ ·')).evaluate().length,
        lessThan(40),
      );
    });

    testWidgets('ızgara: 2 sütun, kaydırdıkça sayfalar gelir', (tester) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
      await tester.pumpAndSettle();
      await openLessonsHub(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lessons_pagedGrid')),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('lessons_pagedGrid')));
      await settle(tester);

      expect(counter(tester), '20 / 500 kayıt');
      // Telefon genişliğinde iki sütun: 1 ve 2 yan yana, 3 alt satırda.
      final one = tester.getTopLeft(find.byKey(const Key('gridCard_1')));
      final two = tester.getTopLeft(find.byKey(const Key('gridCard_2')));
      final three = tester.getTopLeft(find.byKey(const Key('gridCard_3')));
      expect(two.dy, one.dy);
      expect(two.dx, greaterThan(one.dx));
      expect(three.dy, greaterThan(one.dy));
      expect(find.byKey(const Key('gridCard_21')), findsNothing);

      final grid = find.byKey(const Key('pagedGrid_grid_standard'));
      var guard = 0;
      while (find.byKey(const Key('pagedList_end')).evaluate().isEmpty) {
        await tester.drag(grid, const Offset(0, -3000));
        await settle(tester);
        expect(guard++, lessThan(200), reason: 'ızgara sonuna ulaşılamadı');
      }
      expect(counter(tester), '500 / 500 kayıt');
      expect(find.byKey(const Key('gridCard_500')), findsOneWidget);
      // GridView da yalnızca görünen kartları oluşturur.
      expect(find.byType(ExpenseGridCard).evaluate().length, lessThan(40));
    });
  });
}
