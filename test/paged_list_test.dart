import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/dummy_sample_expense_repository.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_cubit.dart';
import 'package:flutter_ders/app/views/view_paged_list/cubit/paged_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İstekleri sayan, istenirse hata veren depo.
class _CountingRepository implements SampleExpenseRepository {
  final _inner = DummySampleExpenseRepository(delay: Duration.zero);
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
  group('sahte depo', () {
    final repo = DummySampleExpenseRepository(delay: Duration.zero);

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

    test('her açılışta aynı liste üretilir', () async {
      final other = DummySampleExpenseRepository(delay: Duration.zero);
      final a = await repo.fetchPage(page: 3, pageSize: 20);
      final b = await other.fetchPage(page: 3, pageSize: 20);
      expect(a.items, b.items);
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
      // Testte "ağ" beklemesin.
      getIt
        ..unregister<SampleExpenseRepository>()
        ..registerSingleton<SampleExpenseRepository>(
          DummySampleExpenseRepository(delay: Duration.zero),
        );
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

    testWidgets('kaydırdıkça sayfalar gelir, 500\'de durur', (tester) async {
      tester.view.physicalSize = const Size(1440, 3120);
      tester.view.devicePixelRatio = 3.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const HarcamaApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('expensesView_pagedList')),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('expensesView_pagedList')));
      await settle(tester);

      expect(counter(tester), '20 / 500 kayıt');
      expect(find.textContaining('#1 ·'), findsOneWidget);
      // 2. sayfa henüz istenmedi.
      expect(find.textContaining('#21 ·'), findsNothing);

      final list = find.byKey(const Key('pagedList_list'));
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
  });
}
