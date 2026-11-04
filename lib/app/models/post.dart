import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

// DERS 16 — json_serializable: `fromJson` / `toJson` elle yazılmaz;
// `dart run build_runner build` post.g.dart dosyasını üretir. Retrofit
// cevabı bu fonksiyonlarla tipli nesneye çevirir.

/// jsonplaceholder'daki bir yazı.
@JsonSerializable()
class Post extends Equatable {
  /// Yazı oluşturur.
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  /// JSON'dan (üretilen kod).
  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  /// Kimlik.
  final int id;

  /// Yazan kullanıcı.
  final int userId;

  /// Başlık.
  final String title;

  /// Metin.
  final String body;

  /// JSON'a (üretilen kod).
  Map<String, dynamic> toJson() => _$PostToJson(this);

  @override
  List<Object?> get props => [id, userId, title, body];
}

/// Yeni yazı ya da tam güncelleme (PUT) gövdesi: kimliği sunucu verir.
@JsonSerializable()
class PostDraft {
  /// Taslak oluşturur.
  const PostDraft({
    required this.userId,
    required this.title,
    required this.body,
  });

  /// JSON'dan (üretilen kod).
  factory PostDraft.fromJson(Map<String, dynamic> json) =>
      _$PostDraftFromJson(json);

  /// Yazan kullanıcı.
  final int userId;

  /// Başlık.
  final String title;

  /// Metin.
  final String body;

  /// JSON'a (üretilen kod).
  Map<String, dynamic> toJson() => _$PostDraftToJson(this);
}

/// Bir yazının yorumu.
@JsonSerializable()
class Comment {
  /// Yorum oluşturur.
  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  /// JSON'dan (üretilen kod).
  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);

  /// Kimlik.
  final int id;

  /// Yazı kimliği.
  final int postId;

  /// Başlık.
  final String name;

  /// Yazanın e-postası (örnek veri, gerçek kişi değil).
  final String email;

  /// Metin.
  final String body;

  /// JSON'a (üretilen kod).
  Map<String, dynamic> toJson() => _$CommentToJson(this);
}
