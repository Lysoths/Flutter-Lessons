import 'package:equatable/equatable.dart';

/// DERS 13 — Bir günün döviz kurları: 1 birim yabancı para kaç ₺.
final class ExchangeRates extends Equatable {
  /// Kurları oluşturur.
  const ExchangeRates({required this.date, required this.tryPerUnit});

  /// Frankfurter cevabını çözer.
  ///
  /// İstek `base=TRY` ile yapılır; cevap "1 ₺ = 0,02 USD" der. Bize
  /// "1 USD = kaç ₺" lazım olduğu için her değerin tersi alınır.
  ///
  /// ```json
  /// {"amount":1.0,"base":"TRY","date":"2026-11-02",
  ///  "rates":{"EUR":0.017843,"USD":0.020013}}
  /// ```
  factory ExchangeRates.fromFrankfurter(Map<String, Object?> json) {
    final rates = json['rates']! as Map<String, Object?>;
    return ExchangeRates(
      date: DateTime.parse(json['date']! as String),
      tryPerUnit: {
        for (final e in rates.entries) e.key: 1 / (e.value! as num).toDouble(),
      },
    );
  }

  /// Avrupa Merkez Bankası'nın yayın günü.
  final DateTime date;

  /// Para birimi kodu → 1 birimin ₺ karşılığı.
  final Map<String, double> tryPerUnit;

  @override
  List<Object?> get props => [date, tryPerUnit];
}

/// Gösterilen para birimleri ve Türkçe adları.
const kCurrencies = {
  'USD': 'ABD doları',
  'EUR': 'Euro',
  'GBP': 'İngiliz sterlini',
  'CHF': 'İsviçre frangı',
  'JPY': 'Japon yeni',
};
