import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/expense.dart';

/// DERS 13 — Uygulamaya gömülü bir tasarruf ipucu
/// (`assets/data/tasarruf_ipuclari.json`).
final class SavingTip extends Equatable {
  /// Bir ipucu oluşturur.
  const SavingTip({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.monthlySaving,
  });

  /// JSON'dan ipucu oluşturur.
  factory SavingTip.fromJson(Map<String, Object?> json) => SavingTip(
    id: json['id']! as String,
    category: ExpenseCategory.values.byName(json['category']! as String),
    title: json['title']! as String,
    body: json['body']! as String,
    monthlySaving: (json['monthlySaving']! as num).toDouble(),
  );

  /// Benzersiz kimlik.
  final String id;

  /// Hangi harcama kategorisine ait.
  final ExpenseCategory category;

  /// Başlık.
  final String title;

  /// Açıklama.
  final String body;

  /// Tahmini aylık tasarruf (₺).
  final double monthlySaving;

  /// [query] başlıkta veya açıklamada geçiyor mu (büyük/küçük harf
  /// fark etmez).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ||
        title.toLowerCase().contains(q) ||
        body.toLowerCase().contains(q);
  }

  @override
  List<Object?> get props => [id];
}
