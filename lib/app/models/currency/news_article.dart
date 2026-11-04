import 'package:equatable/equatable.dart';

/// DERS 15 — RSS'ten gelen tek haber.
class NewsArticle extends Equatable {
  /// Haber oluşturur.
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.link,
    required this.source,
    required this.publishedAt,
    this.imageUrl,
    this.currencies = const [],
  });

  /// Tekil kimlik (RSS `guid`, yoksa bağlantı).
  final String id;

  /// Başlık.
  final String title;

  /// Kısa özet (HTML temizlenmiş).
  final String summary;

  /// Haberin kaynaktaki adresi.
  final Uri link;

  /// Kaynak adı (ör. "Anadolu Ajansı").
  final String source;

  /// Yayın zamanı (yerel saat).
  final DateTime publishedAt;

  /// Görsel adresi.
  final String? imageUrl;

  /// Haberde geçen takip edilen para birimleri (ör. ['USD', 'EUR']).
  final List<String> currencies;

  @override
  List<Object?> get props => [id];
}

/// Para birimini haber metninde tanıyan kelimeler (küçük harf, Türkçe).
const _keywords = {
  'USD': ['dolar', 'abd para', 'fed '],
  'EUR': ['avro', 'euro', 'avrupa merkez bankası', 'ecb'],
  'GBP': ['sterlin', 'ingiltere merkez bankası'],
  'CHF': ['frank', 'isviçre'],
  'JPY': [' yen ', 'japon'],
  'CAD': ['kanada'],
  'AUD': ['avustralya'],
  'CNY': ['yuan', 'çin'],
  'SEK': ['isveç'],
  'NOK': ['norveç'],
};

/// Metinde geçen para birimi kodları.
List<String> detectCurrencies(String text) {
  final t = ' ${trLower(text)} ';
  return [
    for (final e in _keywords.entries)
      if (e.value.any(t.contains)) e.key,
  ];
}

/// Türkçe küçük harf: `I` → `ı`, `İ` → `i` (Dart'ın `toLowerCase`'i bunu
/// bilmez).
String trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
