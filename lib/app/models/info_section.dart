import 'package:equatable/equatable.dart';

/// DERS 14 — Bilgi ekranlarında tek satır: etiket ve değer.
class InfoEntry extends Equatable {
  /// Satır oluşturur.
  const InfoEntry(this.label, this.value, {this.sensitive = false});

  /// Ne olduğu (ör. "Model").
  final String label;

  /// Değeri; yoksa "—".
  final String value;

  /// Kişiyi tanıtabilecek bilgi (IP, Wi-Fi adı ...): ekranda gizli başlar,
  /// dokununca görünür ve hiçbir zaman konsola yazılmaz.
  final bool sensitive;

  @override
  List<Object?> get props => [label, value, sensitive];
}

/// Başlıklı satır grubu (ör. "Donanım").
class InfoSection extends Equatable {
  /// Bölüm oluşturur.
  const InfoSection({
    required this.id,
    required this.title,
    required this.entries,
  });

  /// Ekranın simge seçtiği anahtar (ör. 'hardware').
  final String id;

  /// Görünen başlık.
  final String title;

  /// Satırlar.
  final List<InfoEntry> entries;

  @override
  List<Object?> get props => [id, title, entries];
}

/// Değer yoksa "—" yazar.
String orDash(Object? value) => switch (value) {
  null => '—',
  final String s when s.trim().isEmpty => '—',
  final List<Object?> l when l.isEmpty => '—',
  final List<Object?> l => l.join(', '),
  final bool b => b ? 'Evet' : 'Hayır',
  _ => '$value',
};
