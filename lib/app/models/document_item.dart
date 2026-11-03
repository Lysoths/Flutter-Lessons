import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Belge türleri.
enum DocumentKind {
  /// Fiş / makbuz görseli.
  image('Görseller', Icons.image_rounded),

  /// Fatura PDF'i.
  pdf('PDF faturalar', Icons.picture_as_pdf_rounded),

  /// Ses kaydı.
  audio('Sesler', Icons.graphic_eq_rounded);

  const DocumentKind(this.label, this.icon);

  /// Liste başlığı.
  final String label;

  /// Liste ikonu.
  final IconData icon;
}

/// Uygulamaya gömülü (assets) tek bir belge.
final class DocumentItem extends Equatable {
  /// Bir belge tanımı oluşturur.
  const DocumentItem({
    required this.title,
    required this.description,
    required this.kind,
    required this.assetPath,
    required this.source,
  });

  /// Görünen ad.
  final String title;

  /// Kısa açıklama.
  final String description;

  /// Türü (görsel, PDF, ses).
  final DocumentKind kind;

  /// `pubspec.yaml`'da tanımlı asset yolu.
  final String assetPath;

  /// Kaynak ve lisans bilgisi (telifsiz dosyalar için de belirtilir).
  final String source;

  @override
  List<Object?> get props => [assetPath];
}

/// Uygulamaya gömülü belgeler (assets/belgeler/).
///
/// Kaynak: Wikimedia Commons, hepsi kamu malı (public domain).
const List<DocumentItem> kDocuments = [
  DocumentItem(
    title: 'Satış fişi (1969)',
    description: 'Abbott and Holder galerisinden bir tablo satış fişi',
    kind: DocumentKind.image,
    assetPath: 'assets/belgeler/fis_1969.jpg',
    source: 'Wikimedia Commons · Kamu malı',
  ),
  DocumentItem(
    title: 'Makbuz (1920)',
    description: 'Berliet otomobil firmasının makbuzu',
    kind: DocumentKind.image,
    assetPath: 'assets/belgeler/makbuz_1920.jpg',
    source: 'Wikimedia Commons · Kamu malı',
  ),
  DocumentItem(
    title: 'Hırdavat faturası',
    description: 'Odell Hardware Company, North Carolina',
    kind: DocumentKind.pdf,
    assetPath: 'assets/belgeler/fatura_hirdavat.pdf',
    source: 'Wikimedia Commons · Kamu malı',
  ),
  DocumentItem(
    title: 'Kereste faturası (1905)',
    description: 'Snow Lumber Company, High Point',
    kind: DocumentKind.pdf,
    assetPath: 'assets/belgeler/fatura_kereste.pdf',
    source: 'Wikimedia Commons · Kamu malı',
  ),
  DocumentItem(
    title: 'Yazar kasa',
    description: 'Kasa çekmecesi açılış sesi',
    kind: DocumentKind.audio,
    assetPath: 'assets/belgeler/yazar_kasa.mp3',
    source: 'Wikimedia Commons · Kamu malı',
  ),
  DocumentItem(
    title: 'Kumbara',
    description: 'Metal kumbaraya düşen bozuk paralar',
    kind: DocumentKind.audio,
    assetPath: 'assets/belgeler/kumbara.mp3',
    source: 'Wikimedia Commons · Kamu malı',
  ),
];
