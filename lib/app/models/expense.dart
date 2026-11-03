import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Harcama kategorileri.
enum ExpenseCategory {
  /// Market ve yiyecek.
  food('Yemek', Icons.restaurant),

  /// Ulaşım.
  transport('Ulaşım', Icons.directions_bus),

  /// Faturalar.
  bills('Fatura', Icons.receipt_long),

  /// Eğlence.
  fun('Eğlence', Icons.celebration),

  /// Diğer her şey.
  other('Diğer', Icons.more_horiz);

  const ExpenseCategory(this.label, this.icon);

  /// Ekranda görünen ad.
  final String label;

  /// Listede görünen ikon.
  final IconData icon;
}

/// Tek bir harcama kaydı.
final class Expense extends Equatable {
  /// Bir harcama oluşturur.
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
  });

  /// Kayıttan (JSON) harcama oluşturur.
  factory Expense.fromJson(Map<String, Object?> json) => Expense(
    id: json['id']! as String,
    amount: (json['amount']! as num).toDouble(),
    category: ExpenseCategory.values.byName(json['category']! as String),
    date: DateTime.parse(json['date']! as String),
    note: (json['note'] as String?) ?? '',
  );

  /// Benzersiz kimlik.
  final String id;

  /// Tutar (₺).
  final double amount;

  /// Kategori.
  final ExpenseCategory category;

  /// Harcama tarihi.
  final DateTime date;

  /// İsteğe bağlı açıklama.
  final String note;

  /// Değiştirilmiş bir kopya döndürür; [id] aynı kalır.
  Expense copyWith({
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? note,
  }) => Expense(
    id: id,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    date: date ?? this.date,
    note: note ?? this.note,
  );

  /// Kayda (JSON) çevirir.
  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'category': category.name,
    'date': date.toIso8601String(),
    'note': note,
  };

  @override
  List<Object?> get props => [id, amount, category, date, note];
}
