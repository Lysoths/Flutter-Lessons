import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/box_3d.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/pulse_card.dart';
import 'package:flutter_ders/app/views/view_animation_control/widgets/pulse_effects.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// DERS 8 — AnimationController ile animasyon kontrolü.
void main() {
  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  /// Animasyonlar sürekli döndüğü için pumpAndSettle yerine kare ilerletir.
  Future<void> frames(WidgetTester tester, [int ms = 600]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String status(WidgetTester tester) => (tester.widget(
    find.descendant(
      of: find.byKey(const Key('object3d_status')),
      matching: find.byType(Text),
    ),
  ) as Text).data!;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_animationControl'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    // Kart listenin sonunda, sağ alttaki + düğmesinin altında kalabilir.
    await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 24));
    await frames(tester);
  }

  Future<void> tapIn(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    // Yalnızca ekranda değilse kaydır; yoksa sahne yukarıda kalsın.
    final screen = Offset.zero & tester.view.physicalSize / 3.75;
    if (f.evaluate().isEmpty || !screen.contains(tester.getCenter(f))) {
      final list = key.startsWith('pulse_') ? 'pulse_list' : 'object3d_list';
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(Key(list)),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
    }
    await tester.tap(f);
    await frames(tester, 300);
  }

  /// 3B panelin başına döner (sahne ve durum yazısı görünsün).
  Future<void> toTop(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('object3d_list')),
      const Offset(0, 2000),
    );
    await frames(tester, 300);
  }

  testWidgets('3B kutu her biçimde altı yüz çizer', (tester) async {
    for (final shape in Shape3D.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Box3D(shape: shape, rotationX: -0.4, rotationY: 0.7),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(Box3D),
          matching: find.byType(Transform),
        ),
        findsNWidgets(6),
        reason: shape.name,
      );
    }
  });

  test('sayfa deep link ile açılamaz', () {
    final clean = AppDeepLinks.sanitize(
      Uri.parse('harcamatakibim://app/animasyon-kontrolu'),
    );
    expect(clean.path, '/');
  });

  testWidgets('3B obje: controller düğmeleri durumu değiştirir', (
    tester,
  ) async {
    await open(tester);
    // Açılışta sürekli tekrar ile döner.
    expect(status(tester), 'İleri');

    await tapIn(tester, 'object3d_stop');
    expect(status(tester), 'Durdu');

    await tapIn(tester, 'object3d_reset');
    expect(status(tester), 'Başta (0.0)');

    await tapIn(tester, 'object3d_reverse');
    // Baştayken geri oynatılacak yer yok.
    expect(status(tester), 'Başta (0.0)');

    await tapIn(tester, 'object3d_play');
    expect(status(tester), 'İleri');

    // Tekrarı kapat: bir kez oynar ve sonda durur.
    await tapIn(tester, 'object3d_loop');
    await frames(tester, 4500);
    await toTop(tester);
    expect(status(tester), 'Bitti (1.0)');

    await tapIn(tester, 'object3d_reverse');
    expect(status(tester), 'Geri');
  });

  testWidgets('3B obje: eğri, obje ve sahne değişir', (tester) async {
    await open(tester);

    await tapIn(tester, 'object3d_curve_elastic');
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('object3d_curve_elastic')),
    );
    expect(chip.selected, isTrue);

    await tapIn(tester, 'object3d_shape_card');
    await frames(tester);
    // Sahneyi görmek için listenin başına dön.
    await toTop(tester);
    expect(tester.widget<Box3D>(find.byType(Box3D)).shape, Shape3D.card);

    final stage = find.byKey(const Key('object3d_stage'));
    final before = tester.getSize(stage).height;
    await tapIn(tester, 'object3d_bigStage');
    await frames(tester);
    await toTop(tester);
    expect(tester.getSize(stage).height, greaterThan(before));
  });

  testWidgets('nabız: 8 efekt, durdurulur ve bpm değişir', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('animationControl_tabPulse')));
    await frames(tester);

    final list = find.byKey(const Key('pulse_list'));
    for (final e in PulseEffect.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('pulse_${e.name}')),
        300,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      expect(find.byKey(Key('pulse_${e.name}')), findsOneWidget);
    }
    expect(find.byType(PulseCard), findsWidgets);

    // bpm kartı en sonda: kaydırıcıyı sağa çek, değer artar.
    final value = find.byKey(const Key('pulse_bpm_value'));
    expect(tester.widget<Text>(value).data, '72 bpm');
    await tester.drag(
      find.byKey(const Key('pulse_bpm_slider')),
      const Offset(200, 0),
    );
    await frames(tester, 200);
    expect(tester.widget<Text>(value).data, isNot('72 bpm'));

    await tapIn(tester, 'pulse_bpm_toggle');
    expect(find.text('Oynat'), findsOneWidget);

    // Sayfadan çık: tüm saatler kapanmalı (yoksa test hata verir).
    await tester.pageBack();
    await frames(tester);
    expect(find.byType(PulseCard), findsNothing);
  });
}
