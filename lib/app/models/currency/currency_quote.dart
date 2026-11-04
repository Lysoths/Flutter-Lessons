import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/currency/currency_info.dart';

/// DERS 15 — Bir para biriminin güncel kuru ve bir önceki güne göre değişimi.
class CurrencyQuote extends Equatable {
  /// Kur oluşturur.
  const CurrencyQuote({
    required this.info,
    required this.tryPerUnit,
    this.previous,
  });

  /// Kod, ad, bayrak.
  final CurrencyInfo info;

  /// 1 birimin ₺ karşılığı.
  final double tryPerUnit;

  /// Önceki günün değeri.
  final double? previous;

  /// Önceki güne göre yüzde değişim; önceki gün yoksa 0.
  double get changePercent => switch (previous) {
    final p? when p != 0 => (tryPerUnit - p) / p * 100,
    _ => 0,
  };

  @override
  List<Object?> get props => [info, tryPerUnit, previous];
}
