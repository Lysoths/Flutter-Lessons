// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Post _$PostFromJson(Map<String, dynamic> json) => Post(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  title: json['title'] as String,
  body: json['body'] as String,
);

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'title': instance.title,
  'body': instance.body,
};

PostDraft _$PostDraftFromJson(Map<String, dynamic> json) => PostDraft(
  userId: (json['userId'] as num).toInt(),
  title: json['title'] as String,
  body: json['body'] as String,
);

Map<String, dynamic> _$PostDraftToJson(PostDraft instance) => <String, dynamic>{
  'userId': instance.userId,
  'title': instance.title,
  'body': instance.body,
};

Comment _$CommentFromJson(Map<String, dynamic> json) => Comment(
  id: (json['id'] as num).toInt(),
  postId: (json['postId'] as num).toInt(),
  name: json['name'] as String,
  email: json['email'] as String,
  body: json['body'] as String,
);

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
  'id': instance.id,
  'postId': instance.postId,
  'name': instance.name,
  'email': instance.email,
  'body': instance.body,
};
