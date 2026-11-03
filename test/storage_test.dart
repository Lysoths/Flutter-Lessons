import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/hive_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/prefs_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/sqflite_note_store.dart';
import 'package:flutter_ders/app/models/storage_note.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// DERS 10 — Yerel depolama: aynı kayıt, üç yöntem.
void main() {
  final older = StorageNote(
    id: 'a',
    title: 'Market',
    amount: 12.5,
    createdAt: DateTime(2026),
  );
  final newer = StorageNote(
    id: 'b',
    title: 'Kahve',
    amount: 40,
    createdAt: DateTime(2026, 2),
  );

  /// Her depo aynı davranışı göstermeli.
  Future<void> behaves(NoteStore store) async {
    await store.open();
    await store.clear();
    await store.add(older);
    await store.add(newer);
    expect(await store.getAll(), [newer, older]);

    await store.delete('b');
    expect(await store.getAll(), [older]);

    await store.addAll([
      for (var i = 0; i < 200; i++)
        StorageNote(
          id: 'toplu_$i',
          title: 'Toplu',
          amount: 1,
          createdAt: DateTime(2025).add(Duration(minutes: i)),
        ),
    ]);
    expect(await store.getAll(), hasLength(201));

    await store.clear();
    expect(await store.getAll(), isEmpty);
  }

  group('SharedPreferences', () {
    test('ekle, sırala, sil, temizle', () async {
      SharedPreferences.setMockInitialValues({});
      await behaves(PrefsNoteStore(await SharedPreferences.getInstance()));
    });

    test(
      'liste tek anahtarda JSON metni; gerçek harcamalara dokunmaz',
      () async {
        SharedPreferences.setMockInitialValues({'expenses': '[]'});
        final prefs = await SharedPreferences.getInstance();
        final store = PrefsNoteStore(prefs);
        await store.add(older);
        expect(
          prefs.getString(PrefsNoteStore.storageKey),
          contains('"title":"Market"'),
        );
        await store.clear();
        expect(prefs.getString('expenses'), '[]');
        expect(await store.rawView(), contains(PrefsNoteStore.storageKey));
      },
    );
  });

  group('Hive', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ders10_hive');
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    HiveNoteStore store() =>
        HiveNoteStore(init: () async => Hive.init(dir.path));

    test('ekle, sırala, sil, temizle', () async {
      await behaves(store());
    });

    test('nesne TypeAdapter ile diske yazılır ve geri okunur', () async {
      final first = store();
      await first.open();
      await first.add(newer);
      await Hive.close();

      final second = store();
      await second.open();
      expect(await second.getAll(), [newer]);
      expect(await second.rawView(), contains('StorageNote(title: Kahve'));
    });
  });

  group('sqflite', () {
    setUpAll(sqfliteFfiInit);

    SqfliteNoteStore store() => SqfliteNoteStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

    test('ekle, sırala, sil, temizle', () async {
      await behaves(store());
    });

    test('tablo SQL ile kurulur, sayım ve toplam SQL ile yapılır', () async {
      final s = store();
      await s.open();
      await s.clear();
      await s.add(older);
      await s.add(newer);
      final raw = await s.rawView();
      expect(raw, contains('CREATE TABLE notes'));
      expect(raw, contains('SELECT COUNT(*) → 2'));
      expect(raw, contains('SELECT SUM(amount) → 52.50'));
      // Son çalışan komut, eklemeydi.
      expect(s.sqlLog.first, startsWith('INSERT'));
    });
  });

  group('cubit', () {
    test('aynı cubit her depoyla çalışır: ekle ve ölç', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = StorageDemoCubit(
        store: PrefsNoteStore(await SharedPreferences.getInstance()),
      );
      await cubit.load();
      await cubit.addSample();
      expect(cubit.state.notes, hasLength(1));

      await cubit.benchmark(100);
      expect(cubit.state.benchmark?.count, 100);
      expect(cubit.state.notes, hasLength(100));
      expect(cubit.state.raw, contains(PrefsNoteStore.storageKey));
      await cubit.close();
    });
  });

  testWidgets('merkez sayfa üç ekranı listeler, ilk ekran kayıt ekler', (
    tester,
  ) async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HarcamaApp());
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('expensesView_storage'));
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
    await tester.pumpAndSettle();

    for (final k in StorageKind.values) {
      expect(find.byKey(Key('storageHub_${k.name}')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('storageHub_sharedPreferences')));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const Key('storage_list_sharedPreferences')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('storage_count')),
      300,
      scrollable: list.first,
    );
    expect(find.text('Kayıtlar (0)'), findsOneWidget);
    await tester.drag(list.first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('storage_add')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('storage_count')),
      300,
      scrollable: list.first,
    );
    expect(find.text('Kayıtlar (1)'), findsOneWidget);
  });
}
