import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ders/app/core/firebase/finance_store.dart';
import 'package:flutter_ders/app/core/repository/firestore_expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_firebase/cubit/firestore_lab_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final _source = File('assets/data/firestore_seed.json').readAsStringSync();

void main() {
  group('seed verisi', () {
    final seed = FinanceSeed.parse(_source);
    Set<String> ids(String c) => {
      for (final d in seed.collections[c]!) d['id']! as String,
    };

    test('en az 500 harcama ve ilişkili koleksiyonlar', () {
      expect(
        seed.collections[FinanceCollections.expenses]!.length,
        greaterThanOrEqualTo(500),
      );
      for (final c in FinanceCollections.all) {
        expect(seed.collections[c], isNotEmpty, reason: c);
        expect(ids(c), hasLength(seed.collections[c]!.length), reason: c);
      }
    });

    test('kategori kimlikleri uygulamadaki ExpenseCategory ile aynı', () {
      expect(ids(FinanceCollections.categories), {
        for (final c in ExpenseCategory.values) c.name,
      });
    });

    test('her ilişkinin karşılığı var (kurallar da bunu ister)', () {
      final cats = ids(FinanceCollections.categories);
      for (final d in seed.collections[FinanceCollections.expenses]!) {
        expect(cats, contains(d['kategoriId']));
        expect(
          ids(FinanceCollections.paymentMethods),
          contains(d['odemeYontemiId']),
        );
        if (d['magazaId'] case final m?) {
          expect(ids(FinanceCollections.stores), contains(m));
        }
        expect(
          ids(FinanceCollections.tags).containsAll(d['etiketIdleri']! as List),
          isTrue,
        );
        expect(d['tarih'], isA<DateTime>());
        expect((d['tutar']! as num) > 0, isTrue);
        expect((d['not']! as String).length, lessThanOrEqualTo(200));
      }
      for (final c in [FinanceCollections.stores, FinanceCollections.budgets]) {
        for (final d in seed.collections[c]!) {
          expect(cats, contains(d['kategoriId']), reason: '$c/${d['id']}');
        }
      }
    });

    test('alanlar firestore.rules ile uyumlu', () {
      final rules = File('firestore.rules').readAsStringSync();
      for (final c in FinanceCollections.all) {
        expect(rules, contains('match /$c/{id}'), reason: c);
      }
      const allowed = {
        FinanceCollections.categories: {'ad', 'ikon', 'renk', 'sira'},
        FinanceCollections.paymentMethods: {'ad', 'tur'},
        FinanceCollections.tags: {'ad'},
        FinanceCollections.stores: {'ad', 'kategoriId'},
        FinanceCollections.budgets: {'kategoriId', 'ay', 'limit'},
        FinanceCollections.expenses: {
          'tutar',
          'tarih',
          'not',
          'kategoriId',
          'odemeYontemiId',
          'magazaId',
          'etiketIdleri',
        },
      };
      for (final MapEntry(key: c, value: keys) in allowed.entries) {
        for (final d in seed.collections[c]!) {
          expect(
            keys.containsAll(d.keys.toSet()..remove('id')),
            isTrue,
            reason: '$c/${d['id']}',
          );
        }
      }
    });
  });

  test('ilişkiler çözülür; yeniden eskiye sıralanır', () async {
    final store = MemoryFinanceStore();
    final seed = FinanceSeed.parse(_source);
    await store.seed('u1', seed);
    final snap = await store.read('u1');
    expect(snap.seedVersion, seed.version);
    final rows = seed.collections[FinanceCollections.expenses]!;
    expect(snap.counts[FinanceCollections.expenses], rows.length);
    for (var i = 1; i < snap.expenses.length; i++) {
      expect(
        snap.expenses[i - 1].date.isBefore(snap.expenses[i].date),
        isFalse,
      );
    }
    // İlk harcama: adları kimliklerden çözülmüş olmalı.
    final row = rows.firstWhere((r) => r['id'] == 'h001');
    final e = snap.expenses.firstWhere((e) => e.id == 'h001');
    String nameOf(String c, Object? id) =>
        seed.collections[c]!.firstWhere((d) => d['id'] == id)['ad']! as String;
    expect(
      e.category,
      nameOf(FinanceCollections.categories, row['kategoriId']),
    );
    expect(
      e.paymentMethod,
      nameOf(FinanceCollections.paymentMethods, row['odemeYontemiId']),
    );
    expect(e.tags, [
      for (final t in row['etiketIdleri']! as List)
        nameOf(FinanceCollections.tags, t),
    ]);
    expect(snap.expenses.any((e) => e.store == null), isTrue);
    expect(snap.expenses.any((e) => e.tags.length > 1), isTrue);
    expect((await store.read('baska')).expenses, isEmpty);
  });

  test(
    'yeni seed eski seed kalıntılarını siler, kullanıcı kaydına dokunmaz',
    () async {
      final store = MemoryFinanceStore();
      await store.seed('u1', FinanceSeed.parse(_source));
      store.data['u1']![FinanceCollections.expenses]!
        ..['h01'] = {
          ...store.data['u1']![FinanceCollections.expenses]!['h001']!,
        }
        ..['3f2a-uuid'] = {
          ...store.data['u1']![FinanceCollections.expenses]!['h001']!,
        };
      await store.seed('u1', FinanceSeed.parse(_source));
      final ids = store.data['u1']![FinanceCollections.expenses]!.keys;
      expect(ids, isNot(contains('h01')));
      expect(ids, contains('3f2a-uuid'));
    },
  );

  test('cubit: yükle → tekrar yükle (çoğalmaz) → sil', () async {
    final store = MemoryFinanceStore();
    final cubit = FirestoreLabCubit(
      store: store,
      seedSource: () async => _source,
      uid: () => 'u1',
    );
    await cubit.load();
    expect(cubit.state.snapshot!.expenses, isEmpty);
    await cubit.seed();
    await cubit.seed();
    expect(
      cubit.state.snapshot!.counts[FinanceCollections.expenses],
      greaterThanOrEqualTo(500),
    );
    expect(cubit.state.snapshot!.counts[FinanceCollections.categories], 5);
    await cubit.clear();
    expect(cubit.state.snapshot!.expenses, isEmpty);
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('Firestore belgesi ana ekranın Expense modeline çevrilir', () {
    final e = FirestoreExpenseRepository.fromDoc('h04', {
      'tutar': 1180.75,
      'tarih': Timestamp.fromDate(DateTime.utc(2026, 11, 2, 17)),
      'not': 'Ekim elektrik faturası',
      'kategoriId': 'bills',
      'odemeYontemiId': 'havale',
    });
    expect(e.id, 'h04');
    expect(e.amount, 1180.75);
    expect(e.category, ExpenseCategory.bills);
    expect(e.date.isAtSameMomentAs(DateTime.utc(2026, 11, 2, 17)), isTrue);
    expect(
      FirestoreExpenseRepository.fromDoc('x', {
        'tutar': 5,
        'tarih': Timestamp.now(),
        'kategoriId': 'bilinmeyen',
      }).category,
      ExpenseCategory.other,
    );
  });

  test('cubit: oturum yoksa hiçbir şey yazılmaz', () async {
    final store = MemoryFinanceStore();
    final cubit = FirestoreLabCubit(
      store: store,
      seedSource: () async => _source,
      uid: () => null,
    );
    await cubit.seed();
    expect(store.data, isEmpty);
    expect(cubit.state.snapshot, isNull);
    await cubit.close();
  });
}
