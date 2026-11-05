import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_analytics.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements AppAnalytics {
  final screens = <String>[];
  final events = <(String, Map<String, Object>?)>[];

  @override
  Future<void> logScreen(String name) async => screens.add(name);

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async =>
      events.add((name, params));
}

class _MemoryRepository implements ExpenseRepository {
  List<Expense> items = [];

  @override
  Future<List<Expense>> getAll() async => [...items];

  @override
  Future<void> saveAll(List<Expense> expenses) async => items = [...expenses];
}

void main() {
  test('Firebase başlatılmadıysa olay gönderimi hata vermez', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const a = FirebaseAppAnalytics();
    await a.logScreen('X');
    await a.logEvent('y', {'k': 1});
  });

  group('olay kataloğu', () {
    final names = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

    test('her olay adı Firebase kurallarına uyar ve tektir', () {
      for (final e in AppEvent.values) {
        expect(e.key, matches(names), reason: e.name);
        expect(e.key.startsWith(RegExp('(firebase_|google_|ga_)')), isFalse);
      }
      expect(
        AppEvent.values.map((e) => e.key).toSet(),
        hasLength(AppEvent.values.length),
      );
      expect(AppEvent.values.length, lessThan(500));
      for (final s in AppScreen.values) {
        expect(s.key, matches(names), reason: s.name);
      }
    });

    test('her olay kodda en az bir yerde gönderiliyor', () {
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('app_events.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final unused = [
        for (final e in AppEvent.values)
          if (!RegExp('AppEvent\\.${e.name}\\b').hasMatch(source)) e.name,
      ];
      expect(unused, isEmpty);
    });

    test('her ekranın en az bir olayı var', () {
      final used = {for (final e in AppEvent.values) e.screen};
      final empty = AppScreen.values.where((s) => !used.contains(s));
      // Kategori ekranı yalnız screen_view ile izlenir (eylemi yok).
      expect(empty, [AppScreen.category]);
    });

    test('parametreler: ekran + seçenek, uzun seçenek kırpılır', () {
      expect(AppEvent.currencySelected.params('USD'), {
        'ekran': 'doviz',
        'secenek': 'USD',
      });
      expect(AppEvent.orderRun.params(), {'ekran': 'sync_async'});
      expect(
        (AppEvent.retrofitRun.params('x' * 150)['secenek']! as String).length,
        100,
      );
    });

    test('track: Analytics kayıtlıysa gönderir, değilse sessiz', () async {
      await getIt.reset();
      track(AppEvent.orderRun);
      final rec = _Recorder();
      getIt.registerSingleton<AppAnalytics>(rec);
      track(AppEvent.periodSelected, 'month');
      expect(rec.events.single.$1, 'donem_secildi');
      expect(rec.events.single.$2, {'ekran': 'doviz', 'secenek': 'month'});
      await getIt.reset();
    });
  });

  test('harcama: ekle / düzenle / sil — tutar ve not gönderilmez', () async {
    final rec = _Recorder();
    final cubit = ExpensesCubit(
      repository: _MemoryRepository(),
      analytics: rec,
    );
    final cat = ExpenseCategory.values.first;
    await cubit.add(amount: 125, category: cat, note: 'gizli not');
    final e = cubit.state.expenses.single;
    await cubit.edit(e.copyWith(amount: 99));
    await cubit.remove(e.id);
    expect(rec.events.map((e) => e.$1), [
      'harcama_eklendi',
      'harcama_duzenlendi',
      'harcama_silindi',
    ]);
    for (final (_, p) in rec.events) {
      expect(p!.keys.toSet(), {'ekran', 'secenek'});
      expect(p['secenek'], cat.name);
      expect(p.values.join(), isNot(contains('gizli')));
      expect(p.values.join(), isNot(contains('125')));
    }
    await cubit.close();
  });

  testWidgets('sayfa geçişleri screen_view olur, diyaloglar sayılmaz', (
    tester,
  ) async {
    final rec = _Recorder();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [AnalyticsRouteObserver(rec)],
        home: const SizedBox(),
      ),
    );
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'DetayRoute'),
          builder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    expect(rec.screens, ['/', 'DetayRoute']);
  });
}
