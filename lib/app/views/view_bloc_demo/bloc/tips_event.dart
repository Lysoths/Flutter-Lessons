import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 13 — İpuçları ekranının olayları.
sealed class TipsEvent extends Equatable {
  const TipsEvent();

  @override
  List<Object?> get props => [];
}

/// Ekran açıldı: ipuçları asset'ten okunsun.
final class TipsLoaded extends TipsEvent {
  /// Olayı oluşturur.
  const TipsLoaded();
}

/// Arama kutusuna yazıldı.
final class TipsSearched extends TipsEvent {
  /// [query] için olay oluşturur.
  const TipsSearched(this.query);

  /// Aranan metin.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Kategori seçildi (`null` = hepsi).
final class TipsCategorySelected extends TipsEvent {
  /// [category] için olay oluşturur.
  const TipsCategorySelected(this.category);

  /// Seçilen kategori.
  final ExpenseCategory? category;

  @override
  List<Object?> get props => [category];
}
