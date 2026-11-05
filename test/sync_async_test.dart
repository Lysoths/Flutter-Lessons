import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/helper/sync_async_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// DERS 10 — Sync ve async.
void main() {
  test('busyWork işlemciyi istenen süre meşgul eder', () {
    final watch = Stopwatch()..start();
    final turns = busyWork(60);
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(60));
    expect(turns, greaterThan(0));
  });

  test('event loop sırası: yazıldığı gibi değil, 1 → 7', () async {
    final steps = <String>[];
    await runOrderDemo(steps.add);
    expect(steps.map((s) => s[0]).join(), '1234567');
  });

  test('Isolate.run sonucu ana iş parçacığına döner', () async {
    await WorkMode.isolate.run(30);
  });

  test('sayfa deep link ile açılamaz', () {
    for (final link in ['/sync-async', '/depolama', '/depolama/hive']) {
      expect(AppDeepLinks.sanitize(Uri.parse(link)).path, '/', reason: link);
    }
  });

  testWidgets('async bekleme ekranı dondurmaz, sıra 7 adım gösterir', (
    tester,
  ) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_syncAsync'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 24));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final list = find.descendant(
      of: find.byKey(const Key('syncAsync_list')),
      matching: find.byType(Scrollable),
    );
    final run = find.byKey(const Key('syncAsync_run_asyncWait'));
    await tester.scrollUntilVisible(run, 200, scrollable: list.first);
    await tester.ensureVisible(run);
    await tester.pump();
    await tester.tap(run);
    // 2 saniye boyunca kareler 100 ms arayla akmaya devam eder.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final verdict = find.byKey(const Key('syncAsync_verdict_asyncWait'));
    expect(
      find.descendant(of: verdict, matching: find.text('Ekran AKTI')),
      findsOneWidget,
    );

    final order = find.byKey(const Key('syncAsync_order'));
    await tester.scrollUntilVisible(order, 200, scrollable: list.first);
    await tester.ensureVisible(order);
    await tester.pump();
    await tester.tap(order);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 7; i++) {
      final step = find.byKey(Key('syncAsync_step_$i'), skipOffstage: false);
      expect(step, findsOneWidget);
      expect(tester.widget<Text>(step).data, startsWith('${i + 1} '));
    }
  });
}
