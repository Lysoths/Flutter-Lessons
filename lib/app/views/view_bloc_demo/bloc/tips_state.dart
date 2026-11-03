import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/models/saving_tip.dart';

/// İpuçlarının yüklenme hâli.
enum TipsStatus {
  /// Asset okunuyor.
  loading,

  /// Hazır.
  ready,

  /// Okunamadı.
  failure,
}

/// DERS 13 — İpuçları ekranının durumu.
final class TipsState extends Equatable {
  /// Durumu oluşturur.
  const TipsState({
    this.status = TipsStatus.loading,
    this.all = const [],
    this.query = '',
    this.category,
    this.error,
  });

  /// Yüklenme hâli.
  final TipsStatus status;

  /// Asset'teki tüm ipuçları.
  final List<SavingTip> all;

  /// Arama metni.
  final String query;

  /// Seçili kategori (`null` = hepsi).
  final ExpenseCategory? category;

  /// Hata açıklaması.
  final String? error;

  /// Aramaya ve kategoriye uyan ipuçları. Durumda ayrıca saklanmaz;
  /// her seferinde [all]'dan hesaplanır, böylece ikisi hiç çelişmez.
  List<SavingTip> get visible => [
    for (final t in all)
      if ((category == null || t.category == category) && t.matches(query)) t,
  ];

  /// Görünen ipuçlarının toplam aylık tasarrufu.
  double get visibleSaving =>
      visible.fold(0, (sum, t) => sum + t.monthlySaving);

  /// Değiştirilmiş bir kopya döndürür. [clearCategory] seçimi kaldırır.
  TipsState copyWith({
    TipsStatus? status,
    List<SavingTip>? all,
    String? query,
    ExpenseCategory? category,
    bool clearCategory = false,
    String? error,
  }) => TipsState(
    status: status ?? this.status,
    all: all ?? this.all,
    query: query ?? this.query,
    category: clearCategory ? null : category ?? this.category,
    error: error,
  );

  @override
  List<Object?> get props => [status, all, query, category, error];

  @override
  String toString() =>
      'TipsState(${status.name}, ${visible.length}/${all.length}, '
      '"$query", ${category?.name ?? 'hepsi'})';
}
