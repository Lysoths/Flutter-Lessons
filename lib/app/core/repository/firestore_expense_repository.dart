import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ders/app/core/firebase/finance_store.dart';
import 'package:flutter_ders/app/core/repository/expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 18 — Ana ekranın harcamaları Firestore'dan.
///
/// `kullanicilar/{uid}/harcamalar` okunur ve uygulamanın [Expense]
/// modeline çevrilir (`kategoriId` = [ExpenseCategory] adı). Ekranlar ve
/// cubit değişmez; yalnız DI'de bu sınıf kaydedilir (repository deseni).
///
/// Kaydetme listenin tamamını alır (arayüz böyle); sınıf son bilinen
/// durumla karşılaştırıp yalnız değişen belgeleri yazar, çıkanları siler.
/// Mevcut belgede ödeme yöntemi, mağaza ve etiketler korunur (merge).
/// Oturum yoksa liste boştur ve hiçbir şey yazılmaz.
class FirestoreExpenseRepository implements ExpenseRepository {
  /// Oluşturur; [uid] oturumdaki kullanıcıyı verir.
  FirestoreExpenseRepository({required this._uid, FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String? Function() _uid;

  /// Yeni harcamaların ödeme yöntemi (kurallar bir yöntem ister).
  static const defaultPaymentMethod = 'nakit';

  String? _knownFor;
  Map<String, Expense> _known = {};

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('kullanicilar').doc(uid);

  @override
  Future<List<Expense>> getAll() async {
    final uid = _uid();
    if (uid == null) return const [];
    final snap = await _user(uid)
        .collection(FinanceCollections.expenses)
        .orderBy('tarih', descending: true)
        .get();
    final list = [for (final d in snap.docs) fromDoc(d.id, d.data())];
    _knownFor = uid;
    _known = {for (final e in list) e.id: e};
    return list;
  }

  /// Firestore belgesi → [Expense]. Bilinmeyen kategori "Diğer" olur.
  static Expense fromDoc(String id, Map<String, dynamic> d) => Expense(
    id: id,
    amount: (d['tutar'] as num).toDouble(),
    category:
        ExpenseCategory.values.asNameMap()[d['kategoriId']] ??
        ExpenseCategory.other,
    date: (d['tarih'] as Timestamp).toDate(),
    note: (d['not'] as String?) ?? '',
  );

  @override
  Future<void> saveAll(List<Expense> expenses) async {
    final uid = _uid();
    if (uid == null) return;
    if (_knownFor != uid) await getAll();
    final next = {for (final e in expenses) e.id: e};
    final col = _user(uid).collection(FinanceCollections.expenses);
    final isNew = next.keys.any((id) => !_known.containsKey(id));
    if (isNew) await _ensureReferences(uid);

    final batch = _db.batch();
    for (final id in _known.keys.where((id) => !next.containsKey(id))) {
      batch.delete(col.doc(id));
    }
    for (final e in next.values) {
      final old = _known[e.id];
      if (old == e) continue;
      batch.set(col.doc(e.id), {
        'tutar': e.amount,
        'tarih': Timestamp.fromDate(e.date),
        'not': e.note,
        'kategoriId': e.category.name,
        if (old == null) ...{
          'odemeYontemiId': defaultPaymentMethod,
          'etiketIdleri': <String>[],
        },
      }, SetOptions(merge: true));
    }
    await batch.commit();
    _known = next;
  }

  /// Kurallar harcamanın kategorisini ve ödeme yöntemini arar; örnek veri
  /// yüklenmemiş bir hesapta bunlar önce oluşturulur.
  Future<void> _ensureReferences(String uid) async {
    final user = _user(uid);
    final has = await user
        .collection(FinanceCollections.paymentMethods)
        .doc(defaultPaymentMethod)
        .get();
    if (has.exists) return;
    final batch = _db.batch()
      ..set(user, {'paraBirimi': 'TRY'}, SetOptions(merge: true))
      ..set(
        user
            .collection(FinanceCollections.paymentMethods)
            .doc(defaultPaymentMethod),
        {'ad': 'Nakit', 'tur': 'nakit'},
      );
    for (final (i, c) in ExpenseCategory.values.indexed) {
      batch.set(user.collection(FinanceCollections.categories).doc(c.name), {
        'ad': c.label,
        'sira': i + 1,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
