import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 18 — Firestore: kullanıcıya ait, ilişkili harcama verisi
//
//   kullanicilar/{uid}                  paraBirimi, seedSurumu, olusturuldu
//     ├─ kategoriler/{id}               ad, ikon, renk, sira
//     ├─ odeme_yontemleri/{id}          ad, tur
//     ├─ magazalar/{id}                 ad, kategoriId ─────────► kategoriler
//     ├─ etiketler/{id}                 ad
//     ├─ butceler/{ay_kategori}         kategoriId, ay, limit ──► kategoriler
//     └─ harcamalar/{id}                tutar, tarih, not,
//                                       kategoriId ─────────────► kategoriler
//                                       odemeYontemiId ─────────► odeme_yontemleri
//                                       magazaId? ──────────────► magazalar
//                                       etiketIdleri[] ─────────► etiketler
//
// İlişkiler belge kimliğiyle kurulur (Firestore'da JOIN yok): okurken
// referans koleksiyonlar bir kez okunur, harcamalar kimlikle eşlenir.
// Kategori kimlikleri uygulamadaki ExpenseCategory adlarıyla aynıdır
// (food, transport…). Kurallar firestore.rules'ta; yalnız sahibi erişir.
// ─────────────────────────────────────────────────────────────────────────

/// Koleksiyon adları (yazılış sırasıyla: önce referanslar).
abstract final class FinanceCollections {
  /// Kategoriler.
  static const categories = 'kategoriler';

  /// Ödeme yöntemleri.
  static const paymentMethods = 'odeme_yontemleri';

  /// Etiketler.
  static const tags = 'etiketler';

  /// Mağazalar (→ kategori).
  static const stores = 'magazalar';

  /// Bütçeler (→ kategori).
  static const budgets = 'butceler';

  /// Harcamalar (→ kategori, ödeme, mağaza, etiketler).
  static const expenses = 'harcamalar';

  /// Önce bunlar yazılır: kurallar diğerlerinde bunların varlığını arar.
  static const references = [categories, paymentMethods, tags];

  /// Referanslara bağlı olanlar.
  static const dependents = [stores, budgets, expenses];

  /// Hepsi.
  static const all = [...references, ...dependents];
}

/// `assets/data/firestore_seed.json` içeriği.
class FinanceSeed {
  /// Oluşturur.
  const FinanceSeed({required this.version, required this.collections});

  /// JSON'dan okur. `tarih` alanları ISO metninden zamana çevrilir.
  factory FinanceSeed.parse(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    return FinanceSeed(
      version: j['surum']! as int,
      collections: {
        for (final c in FinanceCollections.all)
          c: [
            for (final row in (j[c]! as List).cast<Map<String, Object?>>())
              {
                for (final MapEntry(:key, :value) in row.entries)
                  key: key == 'tarih'
                      ? DateTime.parse(value! as String)
                      : value,
              },
          ],
      },
    );
  }

  /// Seed sürümü.
  final int version;

  /// Koleksiyon → belgeler (her belgede `id`).
  final Map<String, List<Map<String, Object?>>> collections;

  /// Toplam belge sayısı.
  int get documentCount =>
      collections.values.fold(0, (total, docs) => total + docs.length);
}

/// Harcama, ilişkili adlarıyla birlikte.
class ExpenseRecord extends Equatable {
  /// Oluşturur.
  const ExpenseRecord({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
    required this.category,
    required this.paymentMethod,
    required this.store,
    required this.tags,
  });

  /// Belge kimliği.
  final String id;

  /// Tutar.
  final double amount;

  /// Tarih.
  final DateTime date;

  /// Not.
  final String note;

  /// Kategori adı.
  final String category;

  /// Ödeme yöntemi adı.
  final String paymentMethod;

  /// Mağaza adı (yoksa null).
  final String? store;

  /// Etiket adları.
  final List<String> tags;

  @override
  List<Object?> get props => [
    id,
    amount,
    date,
    note,
    category,
    paymentMethod,
    store,
    tags,
  ];
}

/// Firestore'daki durumun özeti.
class FinanceSnapshot extends Equatable {
  /// Oluşturur.
  const FinanceSnapshot({
    required this.counts,
    required this.expenses,
    this.seedVersion,
  });

  /// Koleksiyon → belge sayısı.
  final Map<String, int> counts;

  /// Harcamalar (yeniden eskiye), ilişkileri çözülmüş.
  final List<ExpenseRecord> expenses;

  /// Kullanıcı belgesindeki seed sürümü (seed yoksa null).
  final int? seedVersion;

  @override
  List<Object?> get props => [counts, expenses, seedVersion];
}

/// Kullanıcının harcama verisi.
abstract interface class FinanceStore {
  /// Seed verisini [uid] kullanıcısının altına yazar (aynı kimliklerle;
  /// tekrar çalıştırmak çoğaltmaz, üzerine yazar).
  Future<void> seed(String uid, FinanceSeed seed);

  /// Okur ve ilişkileri çözer.
  Future<FinanceSnapshot> read(String uid);

  /// [uid] kullanıcısının bütün verisini siler.
  Future<void> clear(String uid);
}

/// İlişkileri çözer (iki uygulama da kullanır).
FinanceSnapshot resolveFinance(
  Map<String, Map<String, Map<String, Object?>>> docs, {
  int? seedVersion,
}) {
  String name(String collection, Object? id) =>
      (docs[collection]?[id]?['ad'] as String?) ?? '?';
  final expenses = [
    for (final MapEntry(key: id, value: d)
        in (docs[FinanceCollections.expenses] ?? const {}).entries)
      ExpenseRecord(
        id: id,
        amount: (d['tutar']! as num).toDouble(),
        date: d['tarih']! as DateTime,
        note: (d['not'] as String?) ?? '',
        category: name(FinanceCollections.categories, d['kategoriId']),
        paymentMethod: name(
          FinanceCollections.paymentMethods,
          d['odemeYontemiId'],
        ),
        store: d['magazaId'] == null
            ? null
            : name(FinanceCollections.stores, d['magazaId']),
        tags: [
          for (final t in (d['etiketIdleri'] as List?) ?? const [])
            name(FinanceCollections.tags, t),
        ],
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));
  return FinanceSnapshot(
    counts: {for (final c in FinanceCollections.all) c: docs[c]?.length ?? 0},
    expenses: expenses,
    seedVersion: seedVersion,
  );
}

/// Cloud Firestore.
class FirestoreFinanceStore implements FinanceStore {
  /// Oluşturur.
  FirestoreFinanceStore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('kullanicilar').doc(uid);

  /// Bir toplu yazmada en çok 500 işlem olabilir; payı bırakıyoruz.
  static const _chunk = 400;

  /// Seed'in koyduğu harcama kimlikleri (`h001`); kullanıcının uygulamadan
  /// eklediği harcamalar (uuid) bu kalıba uymaz, seed onlara dokunmaz.
  static final _seedId = RegExp(r'^h\d+$');

  /// [ops] işlemlerini 400'lük toplu yazmalara bölüp sırayla gönderir.
  Future<void> _commitInChunks(
    List<void Function(WriteBatch batch)> ops,
  ) async {
    for (var i = 0; i < ops.length; i += _chunk) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(_chunk)) {
        op(batch);
      }
      await batch.commit();
    }
  }

  List<void Function(WriteBatch)> _setOps(
    String uid,
    FinanceSeed seed,
    List<String> collections,
  ) => [
    for (final c in collections)
      for (final row in seed.collections[c]!)
        (batch) =>
            batch.set(_user(uid).collection(c).doc(row['id']! as String), {
              for (final MapEntry(:key, :value) in row.entries)
                if (key != 'id')
                  key: value is DateTime ? Timestamp.fromDate(value) : value,
            }),
  ];

  @override
  Future<void> seed(String uid, FinanceSeed seed) async {
    // 1. Önceki seed'den kalan, yeni seed'de olmayan harcamalar silinir.
    final keep = {
      for (final r in seed.collections[FinanceCollections.expenses]!)
        r['id']! as String,
    };
    final old = await _user(uid).collection(FinanceCollections.expenses).get();
    await _commitInChunks([
      for (final d in old.docs)
        if (_seedId.hasMatch(d.id) && !keep.contains(d.id))
          (batch) => batch.delete(d.reference),
    ]);
    // 2. Referanslar: kurallar harcama/mağaza/bütçe yazılırken kategori ve
    //    ödeme yönteminin VAR olduğunu denetler, bu yüzden önce bunlar.
    await _commitInChunks([
      (batch) => batch.set(_user(uid), {
        'olusturuldu': FieldValue.serverTimestamp(),
        'paraBirimi': 'TRY',
        'seedSurumu': seed.version,
      }),
      ..._setOps(uid, seed, FinanceCollections.references),
    ]);
    // 3. Bağlı belgeler (500+ harcama → birkaç toplu yazma).
    await _commitInChunks(_setOps(uid, seed, FinanceCollections.dependents));
  }

  @override
  Future<FinanceSnapshot> read(String uid) async {
    final user = await _user(uid).get();
    final results = await Future.wait([
      for (final c in FinanceCollections.all) _user(uid).collection(c).get(),
    ]);
    final docs = {
      for (final (i, c) in FinanceCollections.all.indexed)
        c: {
          for (final d in results[i].docs)
            d.id: {
              for (final MapEntry(:key, :value) in d.data().entries)
                key: value is Timestamp ? value.toDate() : value,
            },
        },
    };
    return resolveFinance(
      docs,
      seedVersion: user.data()?['seedSurumu'] as int?,
    );
  }

  @override
  Future<void> clear(String uid) async {
    // Bağlı belgeler önce silinir.
    for (final c in FinanceCollections.all.reversed) {
      final snap = await _user(uid).collection(c).get();
      await _commitInChunks([
        for (final d in snap.docs) (batch) => batch.delete(d.reference),
      ]);
    }
    await _user(uid).delete();
  }
}

/// Bellekte çalışan depo (testler).
class MemoryFinanceStore implements FinanceStore {
  /// uid → koleksiyon → kimlik → belge.
  final data = <String, Map<String, Map<String, Map<String, Object?>>>>{};
  final _versions = <String, int>{};

  @override
  Future<void> seed(String uid, FinanceSeed seed) async {
    _versions[uid] = seed.version;
    final user = data.putIfAbsent(uid, () => {});
    final keep = {
      for (final r in seed.collections[FinanceCollections.expenses]!)
        r['id']! as String,
    };
    user[FinanceCollections.expenses]?.removeWhere(
      (id, _) =>
          FirestoreFinanceStore._seedId.hasMatch(id) && !keep.contains(id),
    );
    for (final c in FinanceCollections.all) {
      final col = user.putIfAbsent(c, () => {});
      for (final row in seed.collections[c]!) {
        col[row['id']! as String] = {...row}..remove('id');
      }
    }
  }

  @override
  Future<FinanceSnapshot> read(String uid) async =>
      resolveFinance(data[uid] ?? const {}, seedVersion: _versions[uid]);

  @override
  Future<void> clear(String uid) async {
    data.remove(uid);
    _versions.remove(uid);
  }
}
