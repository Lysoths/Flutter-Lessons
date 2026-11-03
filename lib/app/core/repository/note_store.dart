import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/storage_note.dart';

/// DERS 10 — Yerel depolama türleri.
enum StorageKind {
  /// Anahtar → değer; tarayıcıdaki localStorage gibi.
  sharedPreferences(
    'SharedPreferences',
    'Anahtar-değer',
    Icons.tune_rounded,
    Color(0xFF2563EB),
  ),

  /// NoSQL, nesne temelli kutular (hive_ce: topluluk sürümü).
  hive(
    'Hive (hive_ce)',
    'NoSQL · nesne',
    Icons.hexagon_rounded,
    Color(0xFFF59E0B),
  ),

  /// İlişkisel veritabanı: tablo, satır, SQL.
  sqflite(
    'sqflite',
    'SQL · tablo',
    Icons.table_chart_rounded,
    Color(0xFF10B981),
  );

  const StorageKind(this.label, this.model, this.icon, this.color);

  /// Görünen ad.
  final String label;

  /// Veri modeli.
  final String model;

  /// İkon.
  final IconData icon;

  /// Vurgu rengi.
  final Color color;
}

/// DERS 10 — Kayıtları saklayan yer. Üç ekran aynı arayüzü kullanır;
/// yalnızca arkadaki yöntem değişir (Ders 7'deki depo fikri).
///
/// Bu kayıtlar gerçek harcamalarınızdan AYRI tutulur (ayrı anahtar, kutu
/// ve veritabanı); "Hepsini sil" yalnızca bu dersin verisini siler.
abstract interface class NoteStore {
  /// Hangi yöntem.
  StorageKind get kind;

  /// Depoyu açar (bir kez).
  Future<void> open();

  /// Tüm kayıtlar, en yenisi başta.
  Future<List<StorageNote>> getAll();

  /// Bir kayıt ekler.
  Future<void> add(StorageNote note);

  /// Çok sayıda kaydı tek seferde ekler (hız ölçümü için).
  Future<void> addAll(List<StorageNote> notes);

  /// [id] kimlikli kaydı siler.
  Future<void> delete(String id);

  /// Bu dersin tüm kayıtlarını siler.
  Future<void> clear();

  /// Verinin diskte / bellekte nasıl durduğunu anlatan ham görünüm.
  Future<String> rawView();
}
