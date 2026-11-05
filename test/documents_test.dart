import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/router/app_deep_links.dart';
import 'package:flutter_ders/app/models/document_item.dart';
import 'package:flutter_ders/app/views/view_documents/documents_view.dart';
import 'package:flutter_ders/app/views/view_expenses/expenses_view.dart';
import 'package:flutter_ders/app/views/view_image_viewer/image_viewer_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/lessons.dart';

// DERS 5 — Assets + auto_route.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('her belge pubspec assets içinde gerçekten var', () async {
    for (final d in kDocuments) {
      final data = await rootBundle.load(d.assetPath);
      expect(data.lengthInBytes, greaterThan(1000), reason: d.assetPath);
    }
  });

  test('belgeler linki kabul, tek belge linki reddedilir', () {
    String clean(String link) => AppDeepLinks.sanitize(Uri.parse(link)).path;
    expect(clean('harcamatakibim://app/belgeler'), '/belgeler');
    expect(clean('/belge/pdf'), '/');
    expect(clean('/belge/gorsel'), '/');
    expect(clean('/belgeler/fatura_kereste.pdf'), '/');
  });

  group('uygulamada', () {
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

    testWidgets('ana sayfadan belgeler, oradan görsel açılır', (tester) async {
      await pump(tester);
      await openLessonsHub(tester);
      await tester.tap(find.byKey(const Key('lessons_documents')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentsView), findsOneWidget);
      for (final d in kDocuments) {
        expect(find.text(d.title), findsOneWidget);
      }

      await tester.tap(
        find.byKey(const Key('documentTile_assets/belgeler/fis_1969.jpg')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerView), findsOneWidget);
      expect(find.byKey(const Key('imageViewer_image')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DocumentsView), findsOneWidget);
    });

    testWidgets('belgeler linki listeyi açar', (tester) async {
      await pump(tester);
      await tester.binding.handlePushRoute('/belgeler');
      await tester.pumpAndSettle();
      expect(find.byType(DocumentsView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesView), findsOneWidget);
    });
  });
}
