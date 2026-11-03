import 'package:equatable/equatable.dart';

/// DERS 10 — Üç depolama ekranında da saklanan aynı kayıt.
///
/// Aynı veriyi üç farklı yöntemle saklayınca farklar net görünür:
///   SharedPreferences → JSON metni (anahtar → yazı)
///   Hive              → nesnenin kendisi (TypeAdapter ile ikili biçim)
///   sqflite           → tablodaki bir satır (sütun sütun)
final class StorageNote extends Equatable {
  /// Bir kayıt oluşturur.
  const StorageNote({
    required this.id,
    required this.title,
    required this.amount,
    required this.createdAt,
  });

  /// JSON / tablo satırından kayıt oluşturur.
  factory StorageNote.fromMap(Map<String, Object?> map) => StorageNote(
    id: map['id']! as String,
    title: map['title']! as String,
    amount: (map['amount']! as num).toDouble(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
  );

  /// Benzersiz kimlik.
  final String id;

  /// Başlık (ör. "Market").
  final String title;

  /// Tutar (₺).
  final double amount;

  /// Oluşturulma zamanı.
  final DateTime createdAt;

  /// JSON / tablo satırına çevirir.
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  @override
  List<Object?> get props => [id, title, amount, createdAt];
}
