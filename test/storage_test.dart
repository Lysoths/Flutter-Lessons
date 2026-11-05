import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ders/app/app.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/repository/note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/hive_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/prefs_note_store.dart';
import 'package:flutter_ders/app/core/repository/note_stores/sqflite_note_store.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/models/storage_note.dart';
import 'package:flutter_ders/app/views/view_storage/cubit/storage_demo_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/lessons.dart';

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
      expect(cubit.state.benchmark?.steps, isNotEmpty);
      expect(cubit.state.notes, hasLength(100));
      expect(cubit.state.raw, contains(PrefsNoteStore.storageKey));
      await cubit.close();
    });
  });

  /// [store]'u boşaltıp [n] kayıtla ölçer; adım adlarını döndürür.
  Future<StoreBenchmark> bench(NoteStore store, [int n = 300]) async {
    await store.open();
    await store.clear();
    final result = await store.benchmark([
      for (var i = 0; i < n; i++)
        StorageNote(
          id: 'olcum_$i',
          title: 'Ölçüm',
          amount: 150,
          createdAt: DateTime(2025).add(Duration(minutes: i)),
        ),
    ]);
    // Ölçümden sonra kayıtların hepsi gerçekten depoda.
    expect(await store.getAll(), hasLength(n));
    expect(result.steps.any((s) => s.isWrite), isTrue);
    expect(result.steps.any((s) => !s.isWrite), isTrue);
    return result;
  }

  group('adım adım ölçüm', () {
    test('SharedPreferences: JSON, disk, bellek ve yeniden yükleme', () async {
      SharedPreferences.setMockInitialValues({});
      final r = await bench(
        PrefsNoteStore(await SharedPreferences.getInstance()),
      );
      expect(r.steps.map((s) => s.label), [
        "JSON'a çevir",
        'Diske yaz',
        'Bellekten oku',
        'Metinden nesneye',
        'Diskten yeniden yükle',
      ]);
      expect(r.bytes, greaterThan(300 * 50));
    });

    test(
      'Hive: yazma, kesinleştirme, bellek ve diskten yeniden açma',
      () async {
        final dir = await Directory.systemTemp.createTemp('ders10_bench');
        addTearDown(() async {
          await Hive.close();
          await dir.delete(recursive: true);
        });
        final store = HiveNoteStore(init: () async => Hive.init(dir.path));
        final r = await bench(store);
        expect(r.steps.map((s) => s.label), contains('Diskten yeniden aç'));
        expect(r.bytes, greaterThan(0));
      },
    );

    test('sqflite: yazma, sorgu, dönüşüm, sayım, filtre, toplam', () async {
      sqfliteFfiInit();
      final r = await bench(
        SqfliteNoteStore(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        ),
      );
      expect(r.steps, hasLength(6));
      // Bellekteki veritabanının dosyası yok.
      expect(r.bytes, isNull);
      expect(
        r.steps.firstWhere((s) => s.label == 'Filtre').detail,
        contains('300 satır'),
      );
    });
  });

  test('süre, boyut ve hız okunur yazılır', () {
    expect(formatDuration(const Duration(microseconds: 840)), '840 µs');
    expect(formatDuration(const Duration(microseconds: 12345)), '12,35 ms');
    expect(formatDuration(const Duration(milliseconds: 1250)), '1,25 sn');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(12595), '12,3 KB');
    expect(
      formatPerItem(const Duration(microseconds: 800), 1000),
      '0,8 µs/kayıt',
    );
    expect(
      formatRate(const Duration(milliseconds: 8), 1000),
      '~125.000 kayıt/sn',
    );
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

    await tester.pumpWidget(const HarcamaApp(watchNetwork: false));
    await tester.pumpAndSettle();
    await openLessonsHub(tester);
    final card = find.byKey(const Key('lessons_storage'));
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
