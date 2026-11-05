import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/core/router/route_transitions.dart';
import 'package:flutter_ders/app/views/view_animations/animation_demo_view.dart';
import 'package:flutter_ders/app/views/view_animations/animations_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// DERS 6 — Rota geçiş animasyonları.
void main() {
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

  StackRouter router(WidgetTester tester) =>
      AutoRouter.of(tester.element(find.byType(Navigator).first));

  test('20 farklı senaryo var', () {
    expect(RouteAnimation.values, hasLength(20));
  });

  testWidgets('ana sayfadan vitrin, oradan demo; ileri ve geri', (
    tester,
  ) async {
    await pump(tester);
    await openLessonsHub(tester);
    await tester.ensureVisible(find.byKey(const Key('lessons_animations')));
    await tester.tap(find.byKey(const Key('lessons_animations')));
    await tester.pumpAndSettle();
    expect(find.byType(AnimationsView), findsOneWidget);

    await tester.tap(find.byKey(const Key('animationTile_fade')));
    await tester.pumpAndSettle();
    expect(find.text('Senaryo 1 / 20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('animationDemo_next')));
    await tester.pumpAndSettle();
    expect(find.text('Senaryo 2 / 20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('animationDemo_previous')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animationDemo_previous')));
    await tester.pumpAndSettle();
    // 1'den geri: sona (20) sarar.
    expect(find.text('Senaryo 20 / 20'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AnimationsView), findsOneWidget);
    expect(find.byType(AnimationDemoView), findsNothing);
  });

  testWidgets('20 senaryonun her biri açılır ve ters animasyonla kapanır', (
    tester,
  ) async {
    await pump(tester);
    unawaited(router(tester).push(const AnimationsRoute()));
    await tester.pumpAndSettle();

    for (final a in RouteAnimation.values) {
      unawaited(router(tester).push(AnimationDemoRoute(senaryo: a.name)));
      // push birkaç mikro adımda işlenir: sayfa görünene kadar ilerle.
      final demo = find.byType(AnimationDemoView);
      for (var i = 0; i < 10 && demo.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(demo, findsOneWidget, reason: a.name);

      // Animasyon gerçekten oynuyor mu? (Animasyonsuz senaryo hariç.)
      final status = ModalRoute.of(tester.element(demo))!.animation!.status;
      expect(
        status,
        a == RouteAnimation.none
            ? AnimationStatus.completed
            : AnimationStatus.forward,
        reason: a.name,
      );

      await tester.pumpAndSettle();
      expect(find.text(a.label), findsWidgets, reason: a.name);

      await router(tester).maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(AnimationDemoView), findsNothing, reason: a.name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('yavaş çekim anahtarı süreyi uzatır ve çıkışta sıfırlanır', (
    tester,
  ) async {
    await pump(tester);
    unawaited(router(tester).push(const AnimationsRoute()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animations_slowMotion')));
    await tester.pump();
    expect(timeDilation, 5);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(timeDilation, 1);
  });
}
