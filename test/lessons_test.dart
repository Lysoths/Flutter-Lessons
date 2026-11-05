import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/views/view_documents/documents_view.dart';
import 'package:flutter_ders/app/views/view_lessons/lesson_catalog.dart';
import 'package:flutter_ders/app/views/view_lessons/lessons_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

void main() {
  test('katalog: kimlikler ve rotalar tekil, her konu dolu', () {
    expect(kLessons.map((l) => l.id).toSet(), hasLength(kLessons.length));
    expect(
      kLessons.map((l) => l.route.routeName).toSet(),
      hasLength(kLessons.length),
    );
    for (final topic in LessonTopic.values) {
      expect(kLessons.where((l) => l.topic == topic), isNotEmpty);
    }
  });

  test('ana sayfada ders kartı kalmadı (hepsi katalogda)', () {
    final home = File('lib/app/views/view_expenses/expenses_view.dart')
        .readAsStringSync();
    for (final l in kLessons) {
      expect(
        home.contains('${l.route.routeName}()'),
        isFalse,
        reason: l.route.routeName,
      );
    }
  });

  group('Dersler ekranı', () {
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

    testWidgets('ana sayfadaki kart ve üst düğme dizini açar', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('expensesView_lessons')), findsOneWidget);
      await openLessonsHub(tester);
      expect(find.byType(LessonsView), findsOneWidget);
      expect(find.byKey(const Key('lessons_documents')), findsOneWidget);
    });

    testWidgets('konu süzgeci yalnız o konunun derslerini bırakır', (
      tester,
    ) async {
      await pump(tester);
      await openLessonsHub(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('lessons_topic_architecture')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('lessons_topics')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('lessons_topic_architecture')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessons_bloc')), findsOneWidget);
      expect(find.byKey(const Key('lessons_currency')), findsOneWidget);
      expect(find.byKey(const Key('lessons_documents')), findsNothing);
      // Aynı konuya tekrar basmak süzgeci kaldırır.
      await tester.tap(find.byKey(const Key('lessons_topic_architecture')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessons_documents')), findsOneWidget);
    });

    testWidgets('arama: ada, açıklamaya ve ders numarasına göre', (
      tester,
    ) async {
      await pump(tester);
      await openLessonsHub(tester);
      await tester.enterText(find.byKey(const Key('lessons_search')), 'SFTP');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessons_imageCache')), findsOneWidget);
      expect(find.byKey(const Key('lessons_bloc')), findsNothing);

      await tester.enterText(find.byKey(const Key('lessons_search')), '14');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessons_deviceInfo')), findsOneWidget);
      expect(find.byKey(const Key('lessons_appNetwork')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('lessons_search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessons_empty')), findsOneWidget);
    });

    testWidgets('karta dokununca ders ekranı açılır', (tester) async {
      await pump(tester);
      await openLessonsHub(tester);
      await tester.enterText(find.byKey(const Key('lessons_search')), 'belge');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lessons_documents')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentsView), findsOneWidget);
    });
  });
}
