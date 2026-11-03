import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_ders/app/models/saving_tip.dart';

/// DERS 13 — Tasarruf ipuçlarının nereden geldiğini Bloc'tan gizler.
abstract interface class TipsRepository {
  /// Tüm ipuçlarını getirir.
  Future<List<SavingTip>> loadAll();
}

/// İpuçlarını uygulamaya gömülü JSON dosyasından (asset) okur:
/// `rootBundle.loadString` → `jsonDecode` → `SavingTip.fromJson`.
class AssetTipsRepository implements TipsRepository {
  /// Depoyu oluşturur.
  AssetTipsRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Dosyanın yolu (pubspec → assets/data/).
  static const assetPath = 'assets/data/tasarruf_ipuclari.json';

  final AssetBundle _bundle;

  @override
  Future<List<SavingTip>> loadAll() async {
    final raw = await _bundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<Object?>;
    return [
      for (final item in list)
        SavingTip.fromJson(item! as Map<String, Object?>),
    ];
  }
}
