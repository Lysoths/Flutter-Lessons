import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ana sayfanın üst çubuğundaki düğmeyle Dersler ekranını açar.
Future<void> openLessonsHub(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('expensesView_lessonsAction')));
  await tester.pumpAndSettle();
}
