import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/models/lottie_item.dart';
import 'package:flutter_ders/app/models/lottie_json_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// DERS 9 — Lottie: JSON'dan animasyon.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('her animasyonun JSON dosyası okunur ve anlamlıdır', () async {
    for (final a in kLottieAnimations) {
      final info = await LottieJsonInfo.load(a.assetPath);
      expect(info.frameRate, greaterThan(0), reason: a.id);
      expect(info.outPoint, greaterThan(info.inPoint), reason: a.id);
      expect(info.layerNames, isNotEmpty, reason: a.id);
      expect(info.duration, greaterThan(Duration.zero), reason: a.id);
    }
  });

  test('lottie paketi her dosyayı çözebilir', () async {
    for (final a in kLottieAnimations) {
      final data = await rootBundle.load(a.assetPath);
      final composition = await LottieComposition.fromByteData(data);
      expect(composition.duration, greaterThan(Duration.zero), reason: a.id);
      expect(composition.layers, isNotEmpty, reason: a.id);
    }
  });

  test('JSON bilgileri doğru hesaplanır', () {
    final info = LottieJsonInfo.parse(
      '{"v":"5.0","fr":30,"ip":0,"op":90,"w":100,"h":50,'
      '"layers":[{"nm":"kalp"},{"nm":"gölge"}]}',
    );
    expect(info.frameCount, 90);
    expect(info.duration, const Duration(seconds: 3));
    expect(info.layerNames, ['kalp', 'gölge']);
    expect(info.width, 100);
  });

  test('sayfa deep link ile açılamaz', () {
    final clean = AppDeepLinks.sanitize(
      Uri.parse('harcamatakibim://app/lottie'),
    );
    expect(clean.path, '/');
  });

  testWidgets('sayfa açılır, seçilen animasyonun JSON\'u gösterilir', (
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
    final card = find.byKey(const Key('lessons_lottie'));
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

    // Dosya okuma gerçek G/Ç: sahte saatte bitmez, gerçek zamanda beklenir.
    Future<void> load() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await load();
    expect(find.text('Animasyon = JSON'), findsOneWidget);

    final list = find.byKey(const Key('lottie_list'));
    final chip = find.byKey(const Key('lottieChip_clock'));
    await tester.scrollUntilVisible(
      chip,
      200,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await load();

    final layers = find.byKey(const Key('lottieJson_layers'));
    await tester.scrollUntilVisible(
      layers,
      300,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    // Saat animasyonunda 18 katman var (JSON'daki layers dizisi).
    expect(tester.widget<Text>(layers).data, '18');
    expect(find.byKey(const Key('lottieJson_preview')), findsOneWidget);
  });
}
