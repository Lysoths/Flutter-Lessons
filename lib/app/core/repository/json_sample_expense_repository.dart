import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_ders/app/core/repository/sample_expense_repository.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 7 — Örnek harcamaları uygulamaya gömülü bir JSON dosyasından okur.
///
/// Dosya: `assets/data/ornek_harcamalar.json` (pubspec.yaml → assets).
/// Okuma adımları:
///   1. `rootBundle.loadString(...)` → dosyanın metni
///   2. `jsonDecode(...)`             → `List<Map>` (C#'taki Deserialize)
///   3. `Expense.fromJson(...)`        → her satır bir `Expense` nesnesi
///
/// Dosya yalnızca ilk istekte bir kez okunur, sonra bellekten sayfa
/// sayfa verilir. Gerçek bir sunucu gibi davranması için her sayfa
/// [delay] kadar bekletilir. Hiçbir şey yazılmaz.
class JsonSampleExpenseRepository implements SampleExpenseRepository {
  /// Depoyu oluşturur.
  JsonSampleExpenseRepository({
    this.assetPath = defaultAssetPath,
    this.delay = const Duration(milliseconds: 600),
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  /// Uygulamaya gömülü örnek veri dosyası.
  static const defaultAssetPath = 'assets/data/ornek_harcamalar.json';

  /// Okunan JSON dosyasının yolu.
  final String assetPath;

  /// Her sayfanın "ağdan gelme" süresi.
  final Duration delay;

  final AssetBundle _bundle;

  /// Okunmuş kayıtlar (ilk okumadan sonra dolu).
  List<Expense>? _cache;

  /// Süren okuma; aynı anda gelen istekler dosyayı ikinci kez okumaz.
  Future<List<Expense>>? _loading;

  /// Dosyayı bir kez okur; sonraki çağrılar bellekteki listeyi kullanır.
  Future<List<Expense>> _load() => _loading ??= () async {
    final raw = await _bundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<Object?>;
    return _cache = [
      for (final item in list) Expense.fromJson(item! as Map<String, Object?>),
    ];
  }();

  @override
  Future<ExpensePage> fetchPage({
    required int page,
    required int pageSize,
  }) async {
    if (page < 1 || pageSize < 1) {
      throw ArgumentError('page ve pageSize 1 veya daha büyük olmalı');
    }
    final all = _cache ?? await _load();
    await Future<void>.delayed(delay);
    final total = all.length;
    final from = (page - 1) * pageSize;
    if (from >= total) {
      return (items: <Expense>[], hasMore: false, total: total);
    }
    final to = min(from + pageSize, total);
    return (items: all.sublist(from, to), hasMore: to < total, total: total);
  }
}
